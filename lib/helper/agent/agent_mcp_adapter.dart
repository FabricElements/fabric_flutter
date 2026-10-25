import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../serialized/agent_command_info.dart';
import '../../serialized/agent_param.dart';
import 'agent_bridge.dart';
import 'agent_principal_resolver.dart';

/// Translates MCP JSON-RPC 2.0 requests onto [AgentBridge.handle].
///
/// An MCP client speaks a standard protocol; the bridge speaks its own. This
/// adapter sits between them so any MCP-compatible client can drive a
/// fabric_flutter application through the transports that already exist —
/// no new network server, no new authentication layer.
///
/// The adapter reuses the bridge's configured [AgentAuthorizer] exactly as
/// [AgentBridge.handle] does, so the same token, role, and discovery gates
/// apply. A bearer token travels in the MCP `params._meta.token` field and is
/// injected into the reserved `auth` request parameter before the bridge sees
/// it, matching the envelope described in `doc/agent-bridge-protocol.md`.
///
/// ## Name mapping
///
/// MCP tool names must match `^[a-zA-Z0-9_-]{1,64}$`, so dots in bridge
/// command identifiers are replaced with double underscores. The mapping is
/// built from the bridge's `describe` result so the reverse lookup is exact
/// — it never guesses by replacing `__` back to `.`, which would break any
/// bridge command id that genuinely contains `__`. Commands whose mapped name
/// does not match the MCP pattern are skipped with a [debugPrint].
///
/// | Bridge command id | MCP tool name |
/// | --- | --- |
/// | `element.reveal` | `element__reveal` |
/// | `element.focus` | `element__focus` |
/// | `form.submit` | `form__submit` |
/// | `set_value` | `set_value` (unchanged) |
///
/// ## Error mapping
///
/// | Bridge error | MCP response |
/// | --- | --- |
/// | `not_found`, `invalid_params`, `failed` | Tool result with `isError: true` |
/// | `unauthorized` | JSON-RPC error -32001 |
/// | `disabled` | JSON-RPC error -32002 |
/// | Unknown tool | JSON-RPC error -32602 |
/// | Unknown method | JSON-RPC error -32601 |
/// | Malformed request | JSON-RPC error -32600 |
class AgentMcpAdapter {
  /// Creates an adapter in front of [bridge].
  ///
  /// [appName] and [appVersion] are published in the `initialize` response.
  /// When omitted they are read from the bridge's current configuration.
  AgentMcpAdapter({AgentBridge? bridge, this.appName, this.appVersion})
    : bridge = bridge ?? AgentBridge.instance;

  /// Dispatches authorized requests against the running application.
  final AgentBridge bridge;

  /// Names the application published by `initialize`.
  final String? appName;

  /// Reports the application version published by `initialize`.
  final String? appVersion;

  /// MCP tool name → bridge command id, built from the last `tools/list`.
  final Map<String, String> _nameToId = <String, String>{};

  /// Pattern an MCP tool name must match.
  static final RegExp _mcpNamePattern = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

  /// Returns `true` when [frame] carries the JSON-RPC 2.0 version marker.
  ///
  /// Transports can use this to route MCP frames to [AgentMcpAdapter.handle]
  /// while legacy bridge frames continue unchanged.
  static bool isMcpFrame(Map<String, dynamic>? frame) =>
      frame != null && frame['jsonrpc'] == '2.0';

  /// Handles a decoded MCP JSON-RPC 2.0 [jsonRpc] request.
  ///
  /// Returns `null` for notifications (requests without an `id`), which carry
  /// no response per the JSON-RPC 2.0 specification. Every other outcome is a
  /// decoded response map. This method never throws.
  Future<Map<String, dynamic>?> handle(Map<String, dynamic> jsonRpc) async {
    try {
      // JSON-RPC 2.0 framing: require the version marker.
      if (jsonRpc['jsonrpc'] != '2.0') {
        return _error(
          jsonRpc['id'],
          -32600,
          'The "jsonrpc" field must be "2.0".',
        );
      }

      // Any message without an id is a notification — no response.
      if (!jsonRpc.containsKey('id')) {
        return null;
      }

      final method = jsonRpc['method'];
      if (method is! String || method.isEmpty) {
        return _error(jsonRpc['id'], -32600, 'A "method" is required.');
      }
      final id = jsonRpc['id'];
      final params = jsonRpc['params'];
      final paramsMap = params is Map<String, dynamic>
          ? params
          : <String, dynamic>{};

      switch (method) {
        case 'initialize':
          return _initialize(id, paramsMap);
        case 'ping':
          return _ping(id);
        case 'tools/list':
          return await _toolsList(id, paramsMap);
        case 'tools/call':
          return await _toolsCall(id, paramsMap);
        default:
          return _error(id, -32601, 'Unknown method: $method');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AgentMcpAdapter unexpected error: $error');
      }
      return _error(null, -32603, 'Internal error.');
    }
  }

  /// Returns the MCP server information and capabilities.
  Map<String, dynamic> _initialize(Object? id, Map<String, dynamic> params) {
    final name = appName ?? bridge.appName;
    final version = appVersion ?? bridge.appVersion;
    return <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'result': <String, dynamic>{
        'protocolVersion': '2025-06-18',
        'serverInfo': <String, dynamic>{'name': name, 'version': version},
        'capabilities': <String, dynamic>{
          'tools': <String, dynamic>{'listChanged': false},
        },
      },
    };
  }

  /// Answers a ping with an empty result.
  Map<String, dynamic> _ping(Object? id) => <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'result': <String, dynamic>{},
  };

  /// Lists every bridge command as an MCP tool.
  ///
  /// Builds the name→id map from the `describe` result so `tools/call` can
  /// reverse-lookup exactly without guessing.
  Future<Map<String, dynamic>> _toolsList(
    Object? id,
    Map<String, dynamic> params,
  ) async {
    final bridgeRequest = _bridgeEnvelope('describe', params, id: id);
    final response = await bridge.handle(bridgeRequest);
    if (response['ok'] != true) {
      return _bridgeErrorToMcp(id, response);
    }
    final result =
        response['result'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final commands = result['commands'] as List? ?? <dynamic>[];
    final tools = <Map<String, dynamic>>[];
    _nameToId.clear();
    for (final command in commands) {
      if (command is! Map) continue;
      final info = AgentCommandInfo.fromJson(
        Map<String, dynamic>.from(command),
      );
      final mcpName = _bridgeIdToMcpName(info.id);
      if (!_mcpNamePattern.hasMatch(mcpName)) {
        if (kDebugMode) {
          debugPrint(
            'AgentMcpAdapter: skipping command "${info.id}" — '
            'mapped name "$mcpName" does not match MCP tool name pattern.',
          );
        }
        continue;
      }
      _nameToId[mcpName] = info.id;
      tools.add(_commandToTool(info, mcpName));
    }
    return <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'result': <String, dynamic>{'tools': tools},
    };
  }

  /// Invokes a bridge command addressed by an MCP tool name.
  Future<Map<String, dynamic>> _toolsCall(
    Object? id,
    Map<String, dynamic> params,
  ) async {
    final toolName = params['name'];
    if (toolName is! String || toolName.isEmpty) {
      return _error(id, -32602, 'A tool "name" is required.');
    }
    final commandId = _nameToId[toolName];
    if (commandId == null) {
      return _error(id, -32602, 'Unknown tool: $toolName');
    }
    final arguments = params['arguments'];
    final commandParams = arguments is Map<String, dynamic>
        ? Map<String, dynamic>.from(arguments)
        : <String, dynamic>{};

    final bridgeRequest = _bridgeEnvelope(
      'invoke',
      params,
      id: id,
      commandId: commandId,
      commandParams: commandParams,
    );
    final response = await bridge.handle(bridgeRequest);

    if (response['ok'] == true) {
      final result = response['result'];
      final text = jsonEncode(result);
      final toolResult = <String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': text},
        ],
        'isError': false,
      };
      if (result is Map) {
        toolResult['structuredContent'] = result;
      }
      return <String, dynamic>{
        'jsonrpc': '2.0',
        'id': id,
        'result': toolResult,
      };
    }

    return _bridgeErrorToMcp(id, response);
  }

  /// Builds a bridge request envelope from MCP parameters.
  ///
  /// Extracts the bearer token from `params._meta.token` and injects it into
  /// the reserved `auth` field so the bridge authorizer sees it in the same
  /// location as every other transport. The JSON-RPC [id] is forwarded as the
  /// bridge request id for audit correlation.
  Map<String, dynamic> _bridgeEnvelope(
    String method,
    Map<String, dynamic> mcpParams, {
    required Object? id,
    String? commandId,
    Map<String, dynamic>? commandParams,
  }) {
    final bridgeParams = <String, dynamic>{};
    final meta = mcpParams['_meta'];
    if (meta is Map<String, dynamic>) {
      final token = meta['token'];
      if (token is String && token.isNotEmpty) {
        bridgeParams[AgentPrincipalResolver.authField] = token;
      }
    }
    if (commandId != null) {
      bridgeParams['commandId'] = commandId;
      bridgeParams['params'] = commandParams ?? <String, dynamic>{};
    }
    return <String, dynamic>{
      'id': id,
      'method': method,
      'params': bridgeParams,
    };
  }

  /// Converts a bridge error response into an MCP result or JSON-RPC error.
  ///
  /// Unauthorized and disabled become JSON-RPC protocol errors; every other
  /// bridge error becomes a tool result with `isError: true` per the MCP
  /// convention that tool execution errors are results, not protocol errors.
  Map<String, dynamic> _bridgeErrorToMcp(
    Object? id,
    Map<String, dynamic> response,
  ) {
    final error = response['error'] as Map<String, dynamic>?;
    final code = error?['code'] as String?;
    final message = error?['message'] as String? ?? 'Unknown error.';
    switch (code) {
      case 'unauthorized':
        return _error(
          id,
          -32001,
          message,
          data: <String, dynamic>{'code': 'unauthorized'},
        );
      case 'disabled':
        return _error(
          id,
          -32002,
          message,
          data: <String, dynamic>{'code': 'disabled'},
        );
      default:
        return _toolError(id, message);
    }
  }

  /// Builds a JSON-RPC error response.
  Map<String, dynamic> _error(
    Object? id,
    int code,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final error = <String, dynamic>{'code': code, 'message': message};
    if (data != null) {
      error['data'] = data;
    }
    return <String, dynamic>{'jsonrpc': '2.0', 'id': id, 'error': error};
  }

  /// Builds an MCP tool result that reports an error.
  ///
  /// Per the MCP specification, tool execution errors are reported as
  /// successful tool results with `isError: true`, not as protocol errors.
  Map<String, dynamic> _toolError(Object? id, String message) =>
      <String, dynamic>{
        'jsonrpc': '2.0',
        'id': id,
        'result': <String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': message},
          ],
          'isError': true,
        },
      };

  /// Converts an [AgentCommandInfo] into an MCP tool definition.
  Map<String, dynamic> _commandToTool(AgentCommandInfo info, String mcpName) {
    final properties = <String, dynamic>{};
    final required = <String>[];
    for (final param in info.params) {
      properties[param.name] = _paramToSchema(param);
      if (param.required) {
        required.add(param.name);
      }
    }
    return <String, dynamic>{
      'name': mcpName,
      'title': info.title,
      'description': info.description ?? '',
      'inputSchema': <String, dynamic>{
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required,
      },
    };
  }

  /// Converts an [AgentParam] into a JSON Schema property.
  ///
  /// When [AgentParam.type] is [AgentParamType.any] the `type` key is omitted
  /// so an MCP client does not constrain the value.
  Map<String, dynamic> _paramToSchema(AgentParam param) {
    final schema = <String, dynamic>{};
    if (param.type != AgentParamType.any) {
      schema['type'] = _paramTypeName(param.type);
    }
    if (param.description != null && param.description!.isNotEmpty) {
      schema['description'] = param.description;
    }
    if (param.enumValues != null && param.enumValues!.isNotEmpty) {
      schema['enum'] = param.enumValues;
    }
    return schema;
  }

  /// Returns the JSON Schema type name for [type].
  String _paramTypeName(AgentParamType type) => switch (type) {
    AgentParamType.string => 'string',
    AgentParamType.number => 'number',
    AgentParamType.integer => 'integer',
    AgentParamType.boolean => 'boolean',
    AgentParamType.object => 'object',
    AgentParamType.array => 'array',
    AgentParamType.any => 'any',
  };

  /// Maps a bridge command identifier to an MCP-safe tool name.
  ///
  /// Dots are replaced with double underscores because MCP tool names must
  /// match `^[a-zA-Z0-9_-]{1,64}$`.
  static String _bridgeIdToMcpName(String bridgeId) =>
      bridgeId.replaceAll('.', '__');
}
