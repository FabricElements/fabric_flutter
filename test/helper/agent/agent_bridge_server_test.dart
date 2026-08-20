import 'dart:convert';
import 'dart:io';

import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge_server.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge_server_options.dart';
import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/serialized/agent_audit_record.dart';
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

/// Binds a server on an ephemeral loopback port.
Future<AgentBridgeServer> _start({
  AgentBridge? bridge,
  AgentBridgeServerOptions? options,
  List<AgentAuditRecord>? records,
}) => AgentBridgeServer.start(
  bridge: bridge ?? _bridge(),
  verifier: _verify,
  auditSink: records?.add,
  options: options ?? const AgentBridgeServerOptions(port: 0),
);

/// Posts [payload] to [server] and returns the decoded response.
Future<Map<String, dynamic>> _post(
  AgentBridgeServer server,
  Object payload, {
  String? token,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://${server.host}:${server.port}/'),
    );
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.write(payload is String ? payload : jsonEncode(payload));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      return <String, dynamic>{'status': response.statusCode};
    }
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('AgentBridgeServer', () {
    group('start', () {
      test('should bind the loopback interface by default', () async {
        // Arrange & Act
        final server = await _start();

        // Assert
        expect(server.isRunning, isTrue);
        expect(server.host, AgentBridgeServerOptions.defaultHost);
        expect(server.port, greaterThan(0));
        expect(server.uri.scheme, 'ws');
        await server.stop();
      });

      test('should refuse to start without an authentication gate', () async {
        // Arrange
        final bridge = _bridge();

        // Act & Assert
        await expectLater(
          AgentBridgeServer.start(
            bridge: bridge,
            options: const AgentBridgeServerOptions(port: 0),
          ),
          throwsArgumentError,
        );
      });
    });

    group('http', () {
      test('should serve an authenticated request', () async {
        // Arrange
        final server = await _start();

        // Act
        final response = await _post(server, <String, dynamic>{
          'id': '1',
          'method': 'ping',
        }, token: 'good');

        // Assert
        expect(response['ok'], isTrue);
        await server.stop();
      });

      test('should deny a request without a token', () async {
        // Arrange
        final server = await _start();

        // Act
        final response = await _post(server, <String, dynamic>{
          'id': '1',
          'method': 'ping',
        });

        // Assert
        expect(response['ok'], isFalse);
        expect((response['error'] as Map)['code'], 'unauthorized');
        await server.stop();
      });

      test('should answer malformed JSON with invalid_params', () async {
        // Arrange
        final server = await _start();

        // Act
        final response = await _post(server, '{oops', token: 'good');

        // Assert
        expect(response['ok'], isFalse);
        expect((response['error'] as Map)['code'], 'invalid_params');
        await server.stop();
      });

      test('should reject a body larger than the limit', () async {
        // Arrange
        final server = await _start(
          options: const AgentBridgeServerOptions(port: 0, maxRequestBytes: 64),
        );

        // Act
        final response = await _post(server, <String, dynamic>{
          'id': '1',
          'method': 'invoke',
          'params': <String, dynamic>{
            'commandId': 'echo',
            'params': <String, dynamic>{'blob': 'x' * 500},
          },
        }, token: 'good');

        // Assert
        expect(response['status'], HttpStatus.requestEntityTooLarge);
        await server.stop();
      });

      test('should reject a method other than POST', () async {
        // Arrange
        final server = await _start();
        final client = HttpClient();

        // Act
        final request = await client.getUrl(
          Uri.parse('http://${server.host}:${server.port}/'),
        );
        final response = await request.close();
        await response.drain<void>();

        // Assert
        expect(response.statusCode, HttpStatus.methodNotAllowed);
        client.close(force: true);
        await server.stop();
      });

      test('should record an audit entry for an invoke', () async {
        // Arrange
        final records = <AgentAuditRecord>[];
        final server = await _start(records: records);

        // Act
        await _post(server, <String, dynamic>{
          'id': '1',
          'method': 'invoke',
          'params': <String, dynamic>{
            'commandId': 'echo',
            'params': <String, dynamic>{'note': 'hello'},
          },
        }, token: 'good');

        // Assert
        expect(records.single.transport, 'socket');
        expect(records.single.principalId, 'user-1');
        expect(records.single.params, {'note': '<string:5>'});
        await server.stop();
      });
    });

    group('websocket', () {
      test('should serve a request per text frame', () async {
        // Arrange
        final server = await _start();
        final socket = await WebSocket.connect(
          'ws://${server.host}:${server.port}/?token=good',
        );

        // Act
        socket.add(jsonEncode(<String, dynamic>{'id': '5', 'method': 'ping'}));
        final frame = await socket.first;

        // Assert
        final response = jsonDecode(frame as String) as Map;
        expect(response['ok'], isTrue);
        expect(response['id'], '5');
        await socket.close();
        await server.stop();
      });

      test('should reject a connection past the limit', () async {
        // Arrange
        final server = await _start(
          options: const AgentBridgeServerOptions(port: 0, maxConnections: 1),
        );
        final first = await WebSocket.connect(
          'ws://${server.host}:${server.port}/?token=good',
        );

        // Act & Assert
        await expectLater(
          WebSocket.connect('ws://${server.host}:${server.port}/?token=good'),
          throwsA(isA<WebSocketException>()),
        );
        await first.close();
        await server.stop();
      });
    });

    group('stop', () {
      test('should close the socket and be idempotent', () async {
        // Arrange
        final server = await _start();

        // Act
        await server.stop();
        await server.stop();

        // Assert
        expect(server.isRunning, isFalse);
        await expectLater(
          HttpClient().getUrl(
            Uri.parse('http://${server.host}:${server.port}/'),
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });
}
