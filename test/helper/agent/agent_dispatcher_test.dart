import 'dart:convert';

import 'package:fabric_flutter/helper/agent/agent_audit.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_dispatcher.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/helper/agent/agent_principal_resolver.dart';
import 'package:fabric_flutter/helper/agent/agent_rate_limiter.dart';
import 'package:fabric_flutter/helper/agent/agent_token_authorizer.dart';
import 'package:fabric_flutter/serialized/agent_audit_record.dart';
import 'package:fabric_flutter/serialized/agent_error.dart';
import 'package:fabric_flutter/serialized/agent_principal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an enabled, isolated bridge carrying an `echo` command.
AgentBridge _bridge({bool authenticated = false}) {
  final bridge = AgentBridge(
    elements: AgentElementIndex(),
    navigatorObserver: AgentNavigatorObserver(),
  );
  bridge.configure(
    enabled: true,
    appName: 'Fabric',
    appVersion: '1.0.0',
    authorizer: authenticated
        ? AgentTokenAuthorizer(principals: _resolver())
        : null,
  );
  bridge.registry.register(
    AgentCommand.define(
      id: 'echo',
      title: 'Echo',
      handler: (context) => context.params,
    ),
  );
  bridge.registry.register(
    AgentCommand.define(
      id: 'boom',
      title: 'Boom',
      handler: (context) => throw StateError('nope'),
    ),
  );
  return bridge;
}

/// Builds a resolver that accepts the token `good`.
AgentPrincipalResolver _resolver() => AgentPrincipalResolver(
  verifier: (token) =>
      token == 'good' ? AgentPrincipal(id: 'user-1', role: 'admin') : null,
);

/// Builds an invoke envelope for [commandId].
Map<String, dynamic> _invoke(
  String commandId, {
  Map<String, dynamic>? params,
  String? token,
  String id = '1',
}) => <String, dynamic>{
  'id': id,
  'method': 'invoke',
  'params': <String, dynamic>{
    'commandId': commandId,
    'params': ?params,
    'auth': ?token,
  },
};

void main() {
  group('AgentDispatcher', () {
    group('handleJson', () {
      test('should answer malformed JSON with invalid_params', () async {
        // Arrange
        final dispatcher = AgentDispatcher(bridge: _bridge());

        // Act
        final response = jsonDecode(await dispatcher.handleJson('{not json'));

        // Assert
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'invalid_params');
      });

      test('should answer a non-object payload with invalid_params', () async {
        // Arrange
        final dispatcher = AgentDispatcher(bridge: _bridge());

        // Act
        final response = jsonDecode(await dispatcher.handleJson('[1,2,3]'));

        // Assert
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'invalid_params');
      });

      test('should reject a payload larger than the limit', () async {
        // Arrange
        final dispatcher = AgentDispatcher(
          bridge: _bridge(),
          maxRequestBytes: 32,
        );
        final payload = jsonEncode(
          _invoke('echo', params: {'blob': 'x' * 500}),
        );

        // Act
        final response = jsonDecode(await dispatcher.handleJson(payload));

        // Assert
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'invalid_params');
        expect(response['error']['message'], contains('exceeds'));
      });

      test('should encode a successful response', () async {
        // Arrange
        final dispatcher = AgentDispatcher(bridge: _bridge());

        // Act
        final response = jsonDecode(
          await dispatcher.handleJson(
            jsonEncode(<String, dynamic>{'id': '9', 'method': 'ping'}),
          ),
        );

        // Assert
        expect(response['ok'], isTrue);
        expect(response['id'], '9');
      });
    });

    group('rate limiting', () {
      test('should reject a caller past its budget', () async {
        // Arrange
        final dispatcher = AgentDispatcher(
          bridge: _bridge(),
          rateLimiter: AgentRateLimiter(maxRequests: 1),
        );

        // Act
        final first = await dispatcher.handle(_invoke('echo'));
        final second = await dispatcher.handle(_invoke('echo'));

        // Assert
        expect(first['ok'], isTrue);
        expect(second['ok'], isFalse);
        expect(second['error']['code'], 'failed');
        expect(second['error']['message'], contains('rate limit'));
      });

      test('should bucket connections separately', () async {
        // Arrange
        final dispatcher = AgentDispatcher(
          bridge: _bridge(),
          rateLimiter: AgentRateLimiter(maxRequests: 1),
        );

        // Act
        final first = await dispatcher.handle(
          _invoke('echo'),
          connectionId: 'a',
        );
        final second = await dispatcher.handle(
          _invoke('echo'),
          connectionId: 'b',
        );

        // Assert
        expect(first['ok'], isTrue);
        expect(second['ok'], isTrue);
      });

      test('should bucket an authenticated caller by principal', () async {
        // Arrange
        final resolver = _resolver();
        final dispatcher = AgentDispatcher(
          bridge: _bridge(authenticated: true),
          principals: resolver,
          rateLimiter: AgentRateLimiter(maxRequests: 1),
        );

        // Act
        final first = await dispatcher.handle(
          _invoke('echo', token: 'good'),
          connectionId: 'a',
        );
        final second = await dispatcher.handle(
          _invoke('echo', token: 'good'),
          connectionId: 'b',
        );

        // Assert
        expect(first['ok'], isTrue);
        expect(second['ok'], isFalse);
      });
    });

    group('transport token', () {
      test('should inject a transport credential into the envelope', () async {
        // Arrange
        final resolver = _resolver();
        final dispatcher = AgentDispatcher(
          bridge: _bridge(authenticated: true),
          principals: resolver,
        );

        // Act
        final response = await dispatcher.handle(
          _invoke('echo'),
          token: 'Bearer good',
        );

        // Assert
        expect(response['ok'], isTrue);
      });

      test('should not override a token already in the envelope', () async {
        // Arrange
        final resolver = _resolver();
        final dispatcher = AgentDispatcher(
          bridge: _bridge(authenticated: true),
          principals: resolver,
        );

        // Act
        final response = await dispatcher.handle(
          _invoke('echo', token: 'bad'),
          token: 'good',
        );

        // Assert
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'unauthorized');
      });
    });

    group('audit', () {
      test('should record a successful invocation', () async {
        // Arrange
        final records = <AgentAuditRecord>[];
        final dispatcher = AgentDispatcher(
          bridge: _bridge(authenticated: true),
          principals: _resolver(),
          audit: AgentAuditLog(sink: records.add, debugLog: false),
          transportName: 'in_process',
        );

        // Act
        await dispatcher.handle(
          _invoke('echo', params: {'note': 'hello'}, token: 'good'),
        );

        // Assert
        final record = records.single;
        expect(record.commandId, 'echo');
        expect(record.principalId, 'user-1');
        expect(record.outcome, AgentAuditOutcome.success);
        expect(record.transport, 'in_process');
        expect(record.durationMs, greaterThanOrEqualTo(0));
        expect(record.params, {'note': '<string:5>'});
      });

      test('should never record parameter values or the token', () async {
        // Arrange
        final records = <AgentAuditRecord>[];
        final dispatcher = AgentDispatcher(
          bridge: _bridge(authenticated: true),
          principals: _resolver(),
          audit: AgentAuditLog(sink: records.add, debugLog: false),
        );

        // Act
        await dispatcher.handle(
          _invoke(
            'echo',
            params: {'password': 'hunter2', 'email': 'a@b.co'},
            token: 'good',
          ),
        );

        // Assert
        final encoded = jsonEncode(records.single.toJson());
        expect(encoded, isNot(contains('hunter2')));
        expect(encoded, isNot(contains('a@b.co')));
        expect(encoded, isNot(contains('good')));
        expect(records.single.params['password'], '<redacted>');
      });

      test('should record a failed invocation with its code', () async {
        // Arrange
        final records = <AgentAuditRecord>[];
        final dispatcher = AgentDispatcher(
          bridge: _bridge(),
          audit: AgentAuditLog(sink: records.add, debugLog: false),
        );

        // Act
        await dispatcher.handle(_invoke('boom'));

        // Assert
        expect(records.single.outcome, AgentAuditOutcome.failure);
        expect(records.single.errorCode, AgentErrorCode.failed);
      });

      test('should record an unauthorized invocation', () async {
        // Arrange
        final records = <AgentAuditRecord>[];
        final dispatcher = AgentDispatcher(
          bridge: _bridge(authenticated: true),
          principals: _resolver(),
          audit: AgentAuditLog(sink: records.add, debugLog: false),
        );

        // Act
        await dispatcher.handle(_invoke('echo'));

        // Assert
        expect(records.single.principalId, AgentDispatcher.anonymousPrincipal);
        expect(records.single.errorCode, AgentErrorCode.unauthorized);
      });

      test('should not record discovery methods', () async {
        // Arrange
        final records = <AgentAuditRecord>[];
        final dispatcher = AgentDispatcher(
          bridge: _bridge(),
          audit: AgentAuditLog(sink: records.add, debugLog: false),
        );

        // Act
        await dispatcher.handle(<String, dynamic>{
          'id': '1',
          'method': 'describe',
        });
        await dispatcher.handle(<String, dynamic>{'id': '2', 'method': 'ping'});

        // Assert
        expect(records, isEmpty);
      });
    });

    group('handle', () {
      test('should tolerate a null request', () async {
        // Arrange
        final dispatcher = AgentDispatcher(bridge: _bridge());

        // Act
        final response = await dispatcher.handle(null);

        // Assert
        expect(response['ok'], isFalse);
        expect(response['error']['code'], 'invalid_params');
      });
    });
  });
}
