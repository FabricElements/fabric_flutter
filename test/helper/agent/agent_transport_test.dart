import 'dart:convert';

import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge_server_options.dart';
import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/helper/agent/agent_token_authorizer.dart';
import 'package:fabric_flutter/helper/agent/agent_transport.dart';
import 'package:fabric_flutter/serialized/agent_principal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an enabled, isolated bridge carrying an `echo` command.
AgentBridge _bridge() {
  final bridge = AgentBridge(
    elements: AgentElementIndex(),
    navigatorObserver: AgentNavigatorObserver(),
  );
  bridge.configure(enabled: true, appName: 'Fabric', appVersion: '1.0.0');
  bridge.registry.register(
    AgentCommand.define(
      id: 'echo',
      title: 'Echo',
      handler: (context) => context.params,
    ),
  );
  return bridge;
}

/// Verifies the single token `good`.
AgentPrincipal? _verify(String token) =>
    token == 'good' ? AgentPrincipal(id: 'user-1', role: 'admin') : null;

void main() {
  group('AgentInProcessTransport', () {
    group('start', () {
      test('should refuse to start without an authentication gate', () async {
        // Arrange
        final bridge = _bridge();

        // Act & Assert
        await expectLater(
          AgentInProcessTransport.start(bridge: bridge),
          throwsArgumentError,
        );
      });

      test('should refuse to start while the bridge is disabled', () async {
        // Arrange — the kill switch is off, so no control surface may exist.
        final bridge = AgentBridge();
        bridge.configure(appName: 'Fabric', appVersion: '1.0.0');

        // Act & Assert
        await expectLater(
          AgentInProcessTransport.start(bridge: bridge, verifier: _verify),
          throwsArgumentError,
        );
      });

      test('should start when a verifier is supplied', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final transport = await AgentInProcessTransport.start(
          bridge: bridge,
          verifier: _verify,
        );

        // Assert
        expect(transport.isRunning, isTrue);
        expect(transport.name, 'in_process');
        expect(bridge.authorizer, isA<AgentTokenAuthorizer>());
        await transport.stop();
      });

      test('should start unauthenticated only when opted in', () async {
        // Arrange
        final bridge = _bridge();

        // Act
        final transport = await AgentInProcessTransport.start(
          bridge: bridge,
          options: const AgentBridgeServerOptions(requireAuth: false),
        );

        // Assert
        expect(transport.isRunning, isTrue);
        await transport.stop();
      });
    });

    group('send', () {
      test('should serve an authenticated request', () async {
        // Arrange
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
        );

        // Act
        final response = await transport.send(<String, dynamic>{
          'id': '1',
          'method': 'ping',
          'params': <String, dynamic>{'auth': 'Bearer good'},
        });

        // Assert
        expect(response['ok'], isTrue);
        await transport.stop();
      });

      test('should accept a transport level token', () async {
        // Arrange
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
        );

        // Act
        final response = await transport.send(<String, dynamic>{
          'id': '1',
          'method': 'ping',
        }, token: 'good');

        // Assert
        expect(response['ok'], isTrue);
        await transport.stop();
      });

      test('should deny an unauthenticated request', () async {
        // Arrange
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
        );

        // Act
        final response = await transport.send(<String, dynamic>{
          'id': '1',
          'method': 'ping',
        });

        // Assert
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'unauthorized');
        await transport.stop();
      });

      test('should answer with disabled once stopped', () async {
        // Arrange
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
        );
        await transport.stop();

        // Act
        final response = await transport.send(<String, dynamic>{
          'id': '4',
          'method': 'ping',
          'params': <String, dynamic>{'auth': 'good'},
        });

        // Assert
        expect(transport.isRunning, isFalse);
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'disabled');
        expect(response['id'], '4');
      });

      test('should refuse every method to an unauthenticated caller', () async {
        // Arrange — the defaults a web build ships with, where any script on
        // the page can call the binding.
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
        );

        // Act — no token at all, across the whole method surface.
        final responses = <String, Map<String, dynamic>>{
          for (final method in <String>['ping', 'describe', 'state', 'invoke'])
            method: await transport.send(<String, dynamic>{
              'id': method,
              'method': method,
              'params': <String, dynamic>{'commandId': 'echo'},
            }),
        };

        // Assert — nothing is enumerable: no capability catalog, no route
        // list, no on-screen values, no execution.
        for (final entry in responses.entries) {
          expect(entry.value['ok'], isFalse, reason: entry.key);
          expect(
            entry.value['error']['code'],
            'unauthorized',
            reason: entry.key,
          );
          expect(entry.value['result'], isNull, reason: entry.key);
        }
        expect(jsonEncode(responses), isNot(contains('echo')));
        expect(jsonEncode(responses), isNot(contains('Fabric')));
        await transport.stop();
      });

      test('should allow discovery only when the host opts in', () async {
        // Arrange
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
          requireAuthenticationForDiscovery: false,
        );

        // Act
        final describe = await transport.send(<String, dynamic>{
          'id': '1',
          'method': 'describe',
        });
        final state = await transport.send(<String, dynamic>{
          'id': '2',
          'method': 'state',
        });

        // Assert — discovery opens, but state and execution stay closed.
        expect(describe['ok'], isTrue);
        expect(state['ok'], isFalse);
        expect(state['error']['code'], 'unauthorized');
        await transport.stop();
      });
    });

    group('sendJson', () {
      test('should encode and decode a JSON round trip', () async {
        // Arrange
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
        );

        // Act
        final response = jsonDecode(
          await transport.sendJson(
            jsonEncode(<String, dynamic>{
              'id': '2',
              'method': 'invoke',
              'params': <String, dynamic>{
                'auth': 'good',
                'commandId': 'echo',
                'params': <String, dynamic>{'note': 'hi'},
              },
            }),
          ),
        );

        // Assert
        expect(response['ok'], isTrue);
        expect(response['result']['note'], 'hi');
        await transport.stop();
      });

      test('should answer malformed JSON with invalid_params', () async {
        // Arrange
        final transport = await AgentInProcessTransport.start(
          bridge: _bridge(),
          verifier: _verify,
        );

        // Act
        final response = jsonDecode(await transport.sendJson('}{'));

        // Assert
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'invalid_params');
        await transport.stop();
      });
    });
  });
}
