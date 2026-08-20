import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../log_color.dart';
import 'agent_audit.dart';
import 'agent_bridge.dart';
import 'agent_bridge_server_options.dart';
import 'agent_principal_resolver.dart';
import 'agent_token_authorizer.dart';
import 'agent_transport.dart';

/// Exposes the agent bridge to browser-driving agents through JavaScript.
///
/// A web application cannot open a socket, so the transport is inverted: rather
/// than listening for connections, it installs a callable entry point on
/// `window` — `window.fabricAgentBridge` by default — that any agent already
/// driving the page can call. Playwright, Puppeteer, a Chrome DevTools Protocol
/// client, an extension, or the browser console all reach it the same way:
///
/// ```js
/// const response = await window.fabricAgentBridge({
///   id: '1',
///   method: 'describe',
///   params: { auth: 'Bearer <access token>' },
/// });
/// ```
///
/// The entry point accepts either a JavaScript object or a JSON string, always
/// resolves — a malformed payload resolves with a well-formed `invalid_params`
/// error response rather than rejecting — and resolves with a plain JavaScript
/// object. Because the browser cannot attach an `Authorization` header to the
/// call, the bearer token travels in the reserved `auth` request parameter,
/// exactly as it does on every other transport.
///
/// [AgentBridgeServerOptions.host] and [AgentBridgeServerOptions.port] are
/// ignored here; [AgentBridgeServerOptions.jsBindingName] names the property.
class AgentBridgeServer extends AgentTransport {
  /// Creates a web transport; prefer [start], which installs the binding.
  AgentBridgeServer({required super.dispatcher, required this.options});

  /// Installs the JavaScript entry point in front of [bridge].
  ///
  /// The binding is installed **only** when the bridge is already enabled and
  /// an authentication gate is in place, so a release build that never called
  /// `AgentBridge.instance.configure(enabled: true)` hands no page script a
  /// control surface — `window.fabricAgentBridge` does not exist at all.
  ///
  /// Supplying [verifier] installs an [AgentTokenAuthorizer] on the bridge,
  /// replacing any authorizer previously configured. When it is omitted and
  /// [AgentBridgeServerOptions.requireAuth] is `true`, starting throws an
  /// [ArgumentError] unless the host already installed its own authorizer —
  /// which matters more on the web than anywhere else, because anything running
  /// in the page can call the binding.
  static Future<AgentBridgeServer> start({
    AgentBridgeServerOptions options = const AgentBridgeServerOptions(),
    AgentBridge? bridge,
    AgentTokenVerifier? verifier,
    AgentPrincipalResolver? principals,
    AgentAuditSink? auditSink,
    bool requireAuthenticationForDiscovery = true,
  }) async {
    final dispatcher = AgentTransport.createDispatcher(
      bridge: bridge ?? AgentBridge.instance,
      options: options,
      transportName: transportName,
      verifier: verifier,
      principals: principals,
      auditSink: auditSink,
      requireAuthenticationForDiscovery: requireAuthenticationForDiscovery,
    );
    final server = AgentBridgeServer(dispatcher: dispatcher, options: options);
    server._install();
    return server;
  }

  /// Names this transport in audit records.
  static const String transportName = 'web';

  /// Configures the binding name, limits, and authentication policy.
  final AgentBridgeServerOptions options;

  /// Tracks whether the binding is installed.
  bool _running = false;

  /// Names the transport, always [transportName].
  @override
  String get name => transportName;

  /// Reports whether the JavaScript entry point is installed.
  @override
  bool get isRunning => _running;

  /// Returns the property name installed on `window`.
  String get bindingName => options.jsBindingName;

  /// Returns the page origin, since the web transport binds no interface.
  String get host => web.window.location.hostname;

  /// Returns `0`, because the web transport opens no port.
  int get port => 0;

  /// Returns a descriptive identifier for the installed entry point.
  Uri get uri => Uri(scheme: 'js', path: 'window.$bindingName');

  /// Removes the JavaScript entry point from `window`.
  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    (web.window as JSObject).delete(bindingName.toJS);
  }

  /// Installs the callable entry point on `window`.
  void _install() {
    (web.window as JSObject).setProperty(bindingName.toJS, _handle.toJS);
    _running = true;
  }

  /// Serves one call from JavaScript and resolves with the response object.
  JSPromise<JSAny?> _handle(JSAny? request) => _dispatch(request).toJS;

  /// Converts [request] to JSON, dispatches it, and parses the response back.
  Future<JSAny?> _dispatch(JSAny? request) async {
    final payload = _stringify(request);
    final response = await dispatcher.handleJson(
      payload,
      connectionId: transportName,
    );
    return _parse(response);
  }

  /// Returns [value] as JSON text, whether it arrived as a string or an object.
  ///
  /// A value that cannot be stringified — a circular structure, a function —
  /// yields an empty string, which the dispatcher answers with an
  /// `invalid_params` error instead of throwing across the interop boundary.
  String _stringify(JSAny? value) {
    if (value.isA<JSString>()) return (value! as JSString).toDart;
    try {
      final json = web.window.getProperty<JSObject>('JSON'.toJS);
      final text = json.callMethod<JSString?>('stringify'.toJS, value);
      return text?.toDart ?? '';
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          LogColor.error('The agent bridge could not read the request.'),
        );
      }
      return '';
    }
  }

  /// Returns the JavaScript value described by the JSON [source].
  JSAny? _parse(String source) {
    final json = web.window.getProperty<JSObject>('JSON'.toJS);
    return json.callMethod<JSAny?>('parse'.toJS, source.toJS);
  }
}
