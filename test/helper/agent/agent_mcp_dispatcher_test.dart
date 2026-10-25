import 'dart:convert';

import 'package:fabric_flutter/helper/agent/agent_authorizer.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge_server_options.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/helper/agent/agent_transport.dart';
import 'package:fabric_flutter/serialized/agent_audit_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an enabled bridge backed by an isolated element index.
AgentBridge _bridge() {
  final bridge = AgentBridge(
    elements: AgentElementIndex(),
    navigatorObserver: AgentNavigatorObserver(),
  );
  bridge.configure(
    enabled: true,
    appName: 'Fabric',
    appVersion: '1.0.0',
    authorizer: const AgentAllowAllAuthorizer(),
  );
  return bridge;
}

/// Builds an in-process transport and collects audit records into [records].
AgentInProcessTransport _transport(
  List<AgentAuditRecord> records, {
  AgentBridgeServerOptions options = const AgentBridgeServerOptions(
    requireAuth: false,
  ),
}) => AgentInProcessTransport(
  dispatcher: AgentTransport.createDispatcher(
    bridge: _bridge(),
    options: options,
    transportName: 'test',
    auditSink: records.add,
  ),
);

/// Builds an MCP request map.
Map<String, dynamic> _rpc(String method, {Map<String, dynamic>? params}) =>
    <String, dynamic>{
      'jsonrpc': '2.0',
      'id': '1',
      'method': method,
      'params': ?params,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MCP through AgentDispatcher', () {
    test('should call a tool without a prior tools/list', () async {
      // Arrange
      final transport = _transport([]);

      // Act
      final response = await transport.send(
        _rpc(
          'tools/call',
          params: <String, dynamic>{
            'name': 'element__reveal',
            'arguments': <String, dynamic>{'elementId': 'missing'},
          },
        ),
      );

      // Assert — resolved (a tool result), not -32602
      expect(response!['error'], isNull);
      expect((response['result'] as Map)['isError'], isTrue);
    });

    test('should still reject an unknown tool with -32602', () async {
      // Arrange
      final transport = _transport([]);

      // Act
      final response = await transport.send(
        _rpc('tools/call', params: <String, dynamic>{'name': 'nope'}),
      );

      // Assert
      expect((response!['error'] as Map)['code'], -32602);
    });

    test('should record the MCP invoke in the audit log', () async {
      // Arrange
      final records = <AgentAuditRecord>[];
      final transport = _transport(records);

      // Act
      await transport.send(
        _rpc(
          'tools/call',
          params: <String, dynamic>{
            'name': 'element__reveal',
            'arguments': <String, dynamic>{'elementId': 'missing'},
          },
        ),
      );

      // Assert
      expect(records, hasLength(1));
      expect(records.single.commandId, 'element.reveal');
      expect(records.single.transport, 'test');
    });

    test('should apply the rate limiter to MCP frames', () async {
      // Arrange
      final transport = _transport(
        [],
        options: const AgentBridgeServerOptions(
          requireAuth: false,
          maxRequestsPerWindow: 2,
        ),
      );

      // Act
      final first = await transport.send(_rpc('tools/list'));
      final second = await transport.send(_rpc('tools/list'));
      final third = await transport.send(_rpc('tools/list'));

      // Assert
      expect((first!['result'] as Map)['isError'], isNull);
      expect((second!['result'] as Map)['isError'], isNull);
      expect((third!['result'] as Map)['isError'], isTrue);
    });

    test('should produce no response for a notification', () async {
      // Arrange
      final transport = _transport([]);
      final frame = <String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      };

      // Act
      final map = await transport.send(frame);
      final text = await transport.sendJson(jsonEncode(frame));

      // Assert
      expect(map, isNull);
      expect(text, isNull);
    });

    test('should leave legacy frames unchanged', () async {
      // Arrange
      final transport = _transport([]);

      // Act
      final response = await transport.send(<String, dynamic>{
        'id': '1',
        'method': 'describe',
        'params': <String, dynamic>{},
      });
      final raw = await transport.sendJson(
        jsonEncode(<String, dynamic>{'id': '2', 'method': 'ping'}),
      );

      // Assert
      expect(response!['ok'], isTrue);
      expect(jsonDecode(raw!)['id'], '2');
    });

    test('should apply the size limit to MCP frames', () async {
      // Arrange
      final transport = _transport(
        [],
        options: const AgentBridgeServerOptions(
          requireAuth: false,
          maxRequestBytes: 64,
        ),
      );
      final payload = jsonEncode(
        _rpc('ping', params: <String, dynamic>{'pad': 'x' * 200}),
      );

      // Act
      final raw = await transport.sendJson(payload);

      // Assert
      final response = jsonDecode(raw!) as Map<String, dynamic>;
      expect(response['ok'], isFalse);
      expect((response['error'] as Map)['code'], 'invalid_params');
    });
  });
}
