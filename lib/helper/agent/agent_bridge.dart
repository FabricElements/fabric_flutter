import 'dart:async';

import '../../serialized/agent_describe_result.dart';
import '../../serialized/agent_error.dart';
import '../../serialized/agent_request.dart';
import '../../serialized/agent_response.dart';
import '../../serialized/agent_route_info.dart';
import '../../serialized/agent_state_result.dart';
import 'agent_authorizer.dart';
import 'agent_builtin_commands.dart';
import 'agent_command.dart';
import 'agent_element_index.dart';
import 'agent_exception.dart';
import 'agent_navigator_observer.dart';
import 'agent_registry.dart';

/// Dispatches JSON-RPC-shaped agent requests against the running application.
///
/// The bridge is deliberately transport agnostic: it accepts a decoded request
/// map and returns a decoded response map. A socket server, a JavaScript
/// interop entry point, or an in-process test can all drive it without any
/// protocol change. It performs no networking and no access control of its own;
/// authentication and role checks are supplied through [authorizer].
///
/// The bridge is disabled by default. A host must opt in before any request is
/// served:
///
/// ```dart
/// AgentBridge.instance.configure(
///   enabled: true,
///   appName: 'Example App',
///   appVersion: '1.0.0',
///   routes: [AgentRouteInfo(name: '/dashboard')],
/// );
/// ```
///
/// Requests use the shape
/// `{ "id": "1", "method": "describe" | "state" | "invoke" | "ping", "params": {...} }`
/// and responses use `{ "id": "1", "ok": true, "result": {...} }` or
/// `{ "id": "1", "ok": false, "error": { "code": ..., "message": ... } }`.
class AgentBridge {
  /// Creates a bridge with its own registry, element index, and observer.
  ///
  /// Prefer [instance] in application code. A local bridge is useful in tests
  /// that need full isolation.
  AgentBridge({
    AgentRegistry? registry,
    AgentElementIndex? elements,
    AgentNavigatorObserver? navigatorObserver,
  }) : registry = registry ?? AgentRegistry(),
       elements = elements ?? AgentElementIndex.instance,
       navigatorObserver = navigatorObserver ?? AgentNavigatorObserver.instance;

  /// Provides the shared bridge used by hosts and transports.
  ///
  /// A singleton is used deliberately so a transport running outside the widget
  /// tree can reach it without a `BuildContext`.
  static final AgentBridge instance = AgentBridge();

  /// Names the `describe` method.
  static const String methodDescribe = 'describe';

  /// Names the `state` method.
  static const String methodState = 'state';

  /// Names the `invoke` method.
  static const String methodInvoke = 'invoke';

  /// Names the `ping` method.
  static const String methodPing = 'ping';

  /// Stores the commands an agent can discover and invoke.
  final AgentRegistry registry;

  /// Stores the live index of interactive widgets currently on screen.
  final AgentElementIndex elements;

  /// Reports the route the application is currently showing.
  final AgentNavigatorObserver navigatorObserver;

  /// Reports whether the bridge currently serves requests.
  ///
  /// Defaults to `false`; every request answers with [AgentErrorCode.disabled]
  /// until a host opts in through [configure].
  bool get enabled => _enabled;
  bool _enabled = false;

  /// Names the application published by `describe`.
  String get appName => _appName;
  String _appName = '';

  /// Reports the application version published by `describe`.
  String get appVersion => _appVersion;
  String _appVersion = '';

  /// Lists the routes published by `describe`.
  List<AgentRouteInfo> get routes => List.unmodifiable(_routes);
  List<AgentRouteInfo> _routes = <AgentRouteInfo>[];

  /// Decides whether each request may run.
  ///
  /// This is the seam where the authentication and role layer plugs in. The
  /// default [AgentAllowAllAuthorizer] approves everything, keeping this core
  /// free of access control.
  AgentAuthorizer get authorizer => _authorizer;
  AgentAuthorizer _authorizer = const AgentAllowAllAuthorizer();

  /// Limits how long a single `invoke` may run before it fails.
  ///
  /// A request can shorten this with a `timeoutMs` parameter.
  Duration get commandTimeout => _commandTimeout;
  Duration _commandTimeout = const Duration(seconds: 30);

  /// Applies host configuration and installs the built-in commands.
  ///
  /// Every parameter is optional and only the supplied values change, so this
  /// can be called repeatedly, for example to enable the bridge after the host
  /// has finished registering its own commands. Built-in commands are installed
  /// unless [registerBuiltInCommands] is `false`, and an identifier already
  /// present in [registry] is never overwritten, which lets a host specialize a
  /// built-in command by registering its own version first.
  void configure({
    bool? enabled,
    String? appName,
    String? appVersion,
    List<AgentRouteInfo>? routes,
    AgentAuthorizer? authorizer,
    Duration? commandTimeout,
    bool registerBuiltInCommands = true,
  }) {
    if (enabled != null) _enabled = enabled;
    if (appName != null) _appName = appName;
    if (appVersion != null) _appVersion = appVersion;
    if (routes != null) _routes = List<AgentRouteInfo>.from(routes);
    if (authorizer != null) _authorizer = authorizer;
    if (commandTimeout != null) _commandTimeout = commandTimeout;
    if (registerBuiltInCommands) _installBuiltInCommands();
  }

  /// Restores the bridge to its unconfigured, disabled state.
  ///
  /// Clears the registry, the published routes, and the authorizer. Intended
  /// for tests and for hosts that tear their application down manually. The
  /// element index is left untouched because widgets own its lifecycle.
  void reset() {
    _enabled = false;
    _appName = '';
    _appVersion = '';
    _routes = <AgentRouteInfo>[];
    _authorizer = const AgentAllowAllAuthorizer();
    _commandTimeout = const Duration(seconds: 30);
    registry.clear();
  }

  /// Returns the catalog published by the `describe` method.
  AgentDescribeResult describe() => AgentDescribeResult(
    app: _appName,
    version: _appVersion,
    routes: routes,
    commands: registry.catalog(),
  );

  /// Returns the active route and every element currently indexed on it.
  AgentStateResult state() {
    final route = navigatorObserver.routeName;
    return AgentStateResult(
      route: route,
      path: route,
      params: navigatorObserver.routeParams,
      elements: elements.snapshot(),
    );
  }

  /// Handles a decoded [request] map and returns a decoded response map.
  ///
  /// This is the only entry point a transport needs. It never throws: every
  /// failure is converted into an error response carrying one of the codes in
  /// [AgentErrorCode].
  Future<Map<String, dynamic>> handle(Map<String, dynamic>? request) async {
    final response = await handleRequest(AgentRequest.fromJson(request));
    return response.toJson();
  }

  /// Handles a typed [request] and returns a typed response.
  ///
  /// Prefer [handle] at a transport boundary; this variant is convenient for
  /// in-process callers that already hold an [AgentRequest].
  Future<AgentResponse> handleRequest(AgentRequest request) async {
    if (!_enabled) {
      return _failure(
        request.id,
        AgentErrorCode.disabled,
        'The agent bridge is disabled. Call AgentBridge.configure(enabled: '
        'true) to enable it.',
      );
    }
    try {
      switch (request.method) {
        case methodPing:
          await _authorize(request);
          return AgentResponse.success(
            id: request.id,
            result: <String, dynamic>{
              'pong': true,
              'app': _appName,
              'version': _appVersion,
            },
          );
        case methodDescribe:
          await _authorize(request);
          return AgentResponse.success(
            id: request.id,
            result: describe().toJson(),
          );
        case methodState:
          await _authorize(request);
          return AgentResponse.success(
            id: request.id,
            result: state().toJson(),
          );
        case methodInvoke:
          return AgentResponse.success(
            id: request.id,
            result: await _invoke(request),
          );
        case '':
          throw AgentException.invalidParams('A "method" is required.');
        default:
          throw AgentException.notFound(
            'Unknown method "${request.method}". Expected one of: '
            '$methodDescribe, $methodState, $methodInvoke, $methodPing.',
          );
      }
    } on AgentException catch (error) {
      return AgentResponse.failure(id: request.id, error: error.toError());
    } on TimeoutException catch (error) {
      return _failure(
        request.id,
        AgentErrorCode.failed,
        'The command timed out after ${error.duration?.inMilliseconds}ms.',
      );
    } catch (error) {
      return _failure(request.id, AgentErrorCode.failed, error.toString());
    }
  }

  /// Runs the command addressed by an `invoke` request.
  ///
  /// Throws an [AgentException] when the command is unknown, its parameters are
  /// invalid, the authorizer denies the call, or the handler fails.
  Future<Object?> _invoke(AgentRequest request) async {
    final params = request.params ?? const <String, dynamic>{};
    final commandId = params['commandId'];
    if (commandId is! String || commandId.isEmpty) {
      throw AgentException.invalidParams(
        'Parameter "commandId" is required by invoke.',
      );
    }
    final command = registry.byId(commandId);
    if (command == null) {
      throw AgentException.notFound(
        'No command is registered as "$commandId".',
      );
    }
    final rawParams = params['params'];
    if (rawParams != null && rawParams is! Map) {
      throw AgentException.invalidParams('Parameter "params" must be a map.');
    }
    final commandParams = rawParams == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawParams as Map);
    command.validate(commandParams);
    final authorization = await _authorize(request, command: command);
    final timeoutMs = params['timeoutMs'];
    final timeout = timeoutMs is int
        ? Duration(milliseconds: timeoutMs)
        : _commandTimeout;
    final context = AgentCommandContext(
      commandId: commandId,
      requestId: request.id,
      params: commandParams,
      meta: Map<String, dynamic>.from(authorization.meta),
    );
    return Future<Object?>.sync(
      () => command.handler(context),
    ).timeout(timeout);
  }

  /// Asks the configured authorizer whether [request] may proceed.
  ///
  /// Throws an [AgentException] carrying the authorizer's code and message when
  /// the request is denied.
  Future<AgentAuthorization> _authorize(
    AgentRequest request, {
    AgentCommand? command,
  }) async {
    final authorization = await _authorizer.authorize(
      request,
      command: command,
    );
    if (!authorization.allowed) {
      throw AgentException(
        authorization.code,
        authorization.message.isEmpty
            ? 'The request was not authorized.'
            : authorization.message,
      );
    }
    return authorization;
  }

  /// Builds an error response for [id] from [code] and [message].
  AgentResponse _failure(String id, AgentErrorCode code, String message) =>
      AgentResponse.failure(
        id: id,
        error: AgentError(code: code, message: message),
      );

  /// Registers the built-in commands that are not already present.
  void _installBuiltInCommands() {
    final builtIn = AgentBuiltInCommands(
      registry: registry,
      elements: elements,
      navigatorObserver: navigatorObserver,
      stateReader: state,
    );
    for (final command in builtIn.build()) {
      if (registry.contains(command.id)) continue;
      registry.register(command);
    }
  }
}
