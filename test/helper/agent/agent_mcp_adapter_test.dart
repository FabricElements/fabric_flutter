import 'package:fabric_flutter/helper/agent/agent_authorizer.dart';
import 'package:fabric_flutter/helper/agent/agent_bridge.dart';
import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/agent/agent_mcp_adapter.dart';
import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:fabric_flutter/serialized/agent_route_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an enabled bridge backed by an isolated element index.
AgentBridge _bridge({
  AgentElementIndex? index,
  AgentAuthorizer? authorizer,
  AgentNavigatorObserver? observer,
}) {
  final bridge = AgentBridge(
    elements: index ?? AgentElementIndex(),
    navigatorObserver: observer ?? AgentNavigatorObserver(),
  );
  bridge.configure(
    enabled: true,
    appName: 'Fabric',
    appVersion: '1.0.0',
    authorizer: authorizer ?? const AgentAllowAllAuthorizer(),
    routes: [AgentRouteInfo(name: '/dashboard', title: 'Dashboard')],
  );
  return bridge;
}

/// Builds an MCP JSON-RPC request map.
Map<String, dynamic> _rpc(
  String method, {
  String id = '1',
  Map<String, dynamic>? params,
}) {
  final request = <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'method': method,
  };
  if (params != null) {
    request['params'] = params;
  }
  return request;
}

/// Builds an MCP notification (no id).
Map<String, dynamic> _notification(
  String method, {
  Map<String, dynamic>? params,
}) {
  final request = <String, dynamic>{'jsonrpc': '2.0', 'method': method};
  if (params != null) {
    request['params'] = params;
  }
  return request;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentMcpAdapter', () {
    late AgentBridge bridge;
    late AgentMcpAdapter adapter;

    setUp(() {
      bridge = _bridge();
      adapter = AgentMcpAdapter.forBridge(bridge);
    });

    group('initialize', () {
      test('should return server info and capabilities', () async {
        // Arrange
        final request = _rpc(
          'initialize',
          params: <String, dynamic>{
            'protocolVersion': '2025-06-18',
            'clientInfo': <String, dynamic>{
              'name': 'TestClient',
              'version': '1.0',
            },
          },
        );

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response, isNotNull);
        expect(response!['jsonrpc'], '2.0');
        expect(response['id'], '1');
        final result = response['result'] as Map<String, dynamic>;
        expect(result['protocolVersion'], '2025-06-18');
        final serverInfo = result['serverInfo'] as Map<String, dynamic>;
        expect(serverInfo['name'], 'Fabric');
        expect(serverInfo['version'], '1.0.0');
        final capabilities = result['capabilities'] as Map<String, dynamic>;
        final tools = capabilities['tools'] as Map<String, dynamic>;
        expect(tools['listChanged'], isFalse);
      });

      test('should use adapter appName and appVersion when provided', () async {
        // Arrange
        final customAdapter = AgentMcpAdapter.forBridge(
          bridge,
          appName: 'CustomApp',
          appVersion: '2.0.0',
        );
        final request = _rpc('initialize');

        // Act
        final response = await customAdapter.handle(request);

        // Assert
        final result = response!['result'] as Map<String, dynamic>;
        final serverInfo = result['serverInfo'] as Map<String, dynamic>;
        expect(serverInfo['name'], 'CustomApp');
        expect(serverInfo['version'], '2.0.0');
      });
    });

    group('ping', () {
      test('should return an empty result', () async {
        // Arrange
        final request = _rpc('ping');

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        expect(response['id'], '1');
        expect(response['result'], <String, dynamic>{});
      });
    });

    group('notifications', () {
      test('should return null for any message without an id', () async {
        // Arrange
        final request = <String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'some/method',
        };

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response, isNull);
      });

      test('should return null for notifications/initialized', () async {
        // Arrange
        final request = _notification('notifications/initialized');

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response, isNull);
      });

      test('should return null for other notification methods', () async {
        // Arrange
        final request = _notification('notifications/cancelled');

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response, isNull);
      });
    });

    group('tools/list', () {
      test(
        'should return tools with JSON Schema from bridge commands',
        () async {
          // Arrange
          final request = _rpc('tools/list');

          // Act
          final response = await adapter.handle(request);

          // Assert
          expect(response!['jsonrpc'], '2.0');
          final result = response['result'] as Map<String, dynamic>;
          final tools = result['tools'] as List<dynamic>;
          expect(tools, isNotEmpty);

          // Find set_value tool
          final setValue = tools.cast<Map<String, dynamic>>().firstWhere(
            (t) => t['name'] == 'set_value',
          );
          expect(setValue['title'], isNotEmpty);
          expect(setValue['description'], isNotEmpty);
          final schema = setValue['inputSchema'] as Map<String, dynamic>;
          expect(schema['type'], 'object');
          expect(schema['properties'], isA<Map<String, dynamic>>());
          final props = schema['properties'] as Map<String, dynamic>;
          expect(props.containsKey('elementId'), isTrue);
          expect(props.containsKey('value'), isTrue);
          final required = schema['required'] as List<dynamic>?;
          expect(required, isNotNull);
          expect(required!.contains('elementId'), isTrue);
          // value is optional in set_value
          expect(required.contains('value'), isFalse);
        },
      );

      test('should map dotted command ids to MCP-safe names', () async {
        // Arrange
        final request = _rpc('tools/list');

        // Act
        final response = await adapter.handle(request);

        // Assert
        final tools =
            (response!['result'] as Map<String, dynamic>)['tools']
                as List<dynamic>;
        final names = tools
            .cast<Map<String, dynamic>>()
            .map((t) => t['name'] as String)
            .toSet();

        // Dotted commands use double-underscore
        expect(names.contains('element__reveal'), isTrue);
        expect(names.contains('element__focus'), isTrue);
        expect(names.contains('form__submit'), isTrue);

        // Undotted commands are unchanged
        expect(names.contains('set_value'), isTrue);
        expect(names.contains('navigate'), isTrue);
        expect(names.contains('tap'), isTrue);

        // No raw dots in any tool name
        for (final name in names) {
          expect(
            name.contains('.'),
            isFalse,
            reason: 'Tool name "$name" contains a dot',
          );
        }
      });

      test('should not duplicate screen_state as a tool', () async {
        // Arrange
        final request = _rpc('tools/list');

        // Act
        final response = await adapter.handle(request);

        // Assert
        final tools =
            (response!['result'] as Map<String, dynamic>)['tools']
                as List<dynamic>;
        final names = tools
            .cast<Map<String, dynamic>>()
            .map((t) => t['name'] as String)
            .toList();
        // screen_state is a built-in command — it appears exactly once
        expect(names.where((n) => n == 'screen_state').length, 1);
      });
    });

    group('tools/call', () {
      /// Populates the adapter's name→id map by calling tools/list first.
      Future<void> primeNameMap(AgentMcpAdapter a) async {
        await a.handle(_rpc('tools/list'));
      }

      test(
        'should return success with structuredContent for a Map result',
        () async {
          await primeNameMap(adapter);
          // Arrange
          final request = _rpc(
            'tools/call',
            params: <String, dynamic>{
              'name': 'screen_state',
              'arguments': <String, dynamic>{},
            },
          );

          // Act
          final response = await adapter.handle(request);

          // Assert
          expect(response!['jsonrpc'], '2.0');
          final result = response['result'] as Map<String, dynamic>;
          expect(result['isError'], isFalse);
          expect(result['content'], isA<List>());
          final content = result['content'] as List<dynamic>;
          expect(content, isNotEmpty);
          expect((content.first as Map)['type'], 'text');
          expect(result['structuredContent'], isA<Map<String, dynamic>>());
        },
      );

      test(
        'should map MCP tool name back to bridge command id via name map',
        () async {
          await primeNameMap(adapter);
          // Arrange
          final request = _rpc(
            'tools/call',
            params: <String, dynamic>{
              'name': 'element__reveal',
              'arguments': <String, dynamic>{'elementId': 'test_key'},
            },
          );

          // Act
          final response = await adapter.handle(request);

          // Assert
          // element.reveal with a non-existent key returns a tool error
          expect(response!['jsonrpc'], '2.0');
          final result = response['result'] as Map<String, dynamic>;
          expect(result['isError'], isTrue);
          final content = result['content'] as List<dynamic>;
          expect((content.first as Map)['text'], isNotEmpty);
        },
      );

      test('should return -32602 for a name not in the name map', () async {
        await primeNameMap(adapter);
        // Arrange
        final request = _rpc(
          'tools/call',
          params: <String, dynamic>{
            'name': 'nonexistent_tool',
            'arguments': <String, dynamic>{},
          },
        );

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32602);
      });

      test('should return JSON-RPC error for unauthorized', () async {
        // Arrange — prime the name map on a working bridge, then deny all.
        final denyBridge = _bridge();
        final denyAdapter = AgentMcpAdapter.forBridge(denyBridge);
        await primeNameMap(denyAdapter);
        denyBridge.configure(authorizer: const _DenyAllAuthorizer());
        final request = _rpc(
          'tools/call',
          params: <String, dynamic>{
            'name': 'screen_state',
            'arguments': <String, dynamic>{},
          },
        );

        // Act
        final response = await denyAdapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32001);
        expect(error['data'], isA<Map>());
        expect((error['data'] as Map)['code'], 'unauthorized');
      });

      test('should return JSON-RPC error for disabled bridge', () async {
        // Arrange — prime the name map on an enabled bridge, then disable.
        final disabledBridge = _bridge();
        final disabledAdapter = AgentMcpAdapter.forBridge(disabledBridge);
        await primeNameMap(disabledAdapter);
        disabledBridge.configure(enabled: false);
        final request = _rpc(
          'tools/call',
          params: <String, dynamic>{
            'name': 'screen_state',
            'arguments': <String, dynamic>{},
          },
        );

        // Act
        final response = await disabledAdapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32002);
        expect(error['data'], isA<Map>());
        expect((error['data'] as Map)['code'], 'disabled');
      });

      test('should return -32602 for missing tool name', () async {
        // Arrange
        final request = _rpc('tools/call', params: <String, dynamic>{});

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32602);
      });
    });

    group('error handling', () {
      test('should return -32601 for unknown method', () async {
        // Arrange
        final request = _rpc('unknown/method');

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32601);
      });

      test('should return -32600 for missing method', () async {
        // Arrange
        final request = <String, dynamic>{'jsonrpc': '2.0', 'id': '1'};

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32600);
      });

      test('should return -32600 for empty method', () async {
        // Arrange
        final request = _rpc('');

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32600);
      });

      test('should return -32600 for non-string method', () async {
        // Arrange
        final request = <String, dynamic>{
          'jsonrpc': '2.0',
          'id': '1',
          'method': 42,
        };

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32600);
      });
    });

    group('JSON-RPC framing', () {
      test('should return -32600 when jsonrpc is not "2.0"', () async {
        // Arrange
        final request = <String, dynamic>{
          'jsonrpc': '1.0',
          'id': '1',
          'method': 'ping',
        };

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32600);
      });

      test('should return -32600 when jsonrpc is missing', () async {
        // Arrange
        final request = <String, dynamic>{'id': '1', 'method': 'ping'};

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32600);
      });

      test(
        'should return null for a message without an id (notification)',
        () async {
          // Arrange
          final request = <String, dynamic>{'jsonrpc': '2.0', 'method': 'ping'};

          // Act
          final response = await adapter.handle(request);

          // Assert
          expect(response, isNull);
        },
      );
    });

    group('AgentParamType.any schema', () {
      test('should omit type key for set_value.value', () async {
        // Arrange
        final request = _rpc('tools/list');

        // Act
        final response = await adapter.handle(request);

        // Assert
        final tools =
            (response!['result'] as Map<String, dynamic>)['tools']
                as List<dynamic>;
        final setValue = tools.cast<Map<String, dynamic>>().firstWhere(
          (t) => t['name'] == 'set_value',
        );
        final schema = setValue['inputSchema'] as Map<String, dynamic>;
        final props = schema['properties'] as Map<String, dynamic>;
        final valueSchema = props['value'] as Map<String, dynamic>;
        // AgentParamType.any omits the type key entirely
        expect(valueSchema.containsKey('type'), isFalse);
        expect(valueSchema['description'], isNotEmpty);
      });

      test('should omit type key for wait_for.value', () async {
        // Arrange
        final request = _rpc('tools/list');

        // Act
        final response = await adapter.handle(request);

        // Assert
        final tools =
            (response!['result'] as Map<String, dynamic>)['tools']
                as List<dynamic>;
        final waitFor = tools.cast<Map<String, dynamic>>().firstWhere(
          (t) => t['name'] == 'wait_for',
        );
        final schema = waitFor['inputSchema'] as Map<String, dynamic>;
        final props = schema['properties'] as Map<String, dynamic>;
        final valueSchema = props['value'] as Map<String, dynamic>;
        expect(valueSchema.containsKey('type'), isFalse);
      });

      test('should still emit type for non-any params', () async {
        // Arrange
        final request = _rpc('tools/list');

        // Act
        final response = await adapter.handle(request);

        // Assert
        final tools =
            (response!['result'] as Map<String, dynamic>)['tools']
                as List<dynamic>;
        final setValue = tools.cast<Map<String, dynamic>>().firstWhere(
          (t) => t['name'] == 'set_value',
        );
        final schema = setValue['inputSchema'] as Map<String, dynamic>;
        final props = schema['properties'] as Map<String, dynamic>;
        // elementId is a string param — type must be present
        final elementIdSchema = props['elementId'] as Map<String, dynamic>;
        expect(elementIdSchema['type'], 'string');
      });
    });

    group('name map', () {
      test('should build name→id map from tools/list', () async {
        // Arrange
        final request = _rpc('tools/list');

        // Act
        final response = await adapter.handle(request);

        // Assert
        final tools =
            (response!['result'] as Map<String, dynamic>)['tools']
                as List<dynamic>;
        final names = tools
            .cast<Map<String, dynamic>>()
            .map((t) => t['name'] as String)
            .toSet();
        expect(names.contains('element__reveal'), isTrue);
        expect(names.contains('set_value'), isTrue);
        // No raw dots
        for (final name in names) {
          expect(
            name.contains('.'),
            isFalse,
            reason: 'Tool name "$name" contains a dot',
          );
        }
      });

      test('should return -32602 for a name not in the map', () async {
        // Populate the map first
        await adapter.handle(_rpc('tools/list'));
        // Arrange
        final request = _rpc(
          'tools/call',
          params: <String, dynamic>{
            'name': 'not_in_the_map',
            'arguments': <String, dynamic>{},
          },
        );

        // Act
        final response = await adapter.handle(request);

        // Assert
        expect(response!['jsonrpc'], '2.0');
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], -32602);
      });
    });

    test('should inject _meta.token into bridge auth field', () async {
      // Arrange — prime the name map on a working bridge, then deny all.
      final denyBridge = _bridge();
      final denyAdapter = AgentMcpAdapter.forBridge(denyBridge);
      await denyAdapter.handle(_rpc('tools/list'));
      denyBridge.configure(authorizer: const _DenyAllAuthorizer());
      final request = _rpc(
        'tools/call',
        params: <String, dynamic>{
          'name': 'screen_state',
          'arguments': <String, dynamic>{},
          '_meta': <String, dynamic>{'token': 'test-token-123'},
        },
      );

      // Act
      final response = await denyAdapter.handle(request);

      // Assert
      // The deny-all authorizer rejects everything, confirming the bridge
      // processed the request (with auth injected).
      expect(response!['jsonrpc'], '2.0');
      final error = response['error'] as Map<String, dynamic>;
      expect(error['code'], -32001);
    });
  });
}

/// Denies every request with a fixed message.
class _DenyAllAuthorizer extends AgentAuthorizer {
  const _DenyAllAuthorizer();

  @override
  AgentAuthorization authorize(
    covariant dynamic request, {
    AgentCommand? command,
  }) => const AgentAuthorization.deny('Nope.');
}
