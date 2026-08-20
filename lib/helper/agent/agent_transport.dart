import 'dart:async';
import 'dart:convert';

import '../../serialized/agent_error.dart';
import '../../serialized/agent_response.dart';
import 'agent_audit.dart';
import 'agent_authorizer.dart';
import 'agent_bridge.dart';
import 'agent_bridge_server_options.dart';
import 'agent_dispatcher.dart';
import 'agent_principal_resolver.dart';
import 'agent_rate_limiter.dart';
import 'agent_token_authorizer.dart';

/// Carries agent requests between an external caller and an [AgentBridge].
///
/// A transport owns nothing but framing: it decodes an incoming payload, hands
/// it to its [dispatcher], and writes the encoded response back. Every safety
/// control — request size, rate limiting, auditing — lives in the dispatcher,
/// and every access decision lives in the bridge's authorizer, so adding a
/// transport can never widen the attack surface by accident.
abstract class AgentTransport {
  /// Creates a transport bound to [dispatcher].
  AgentTransport({required this.dispatcher});

  /// Applies the safety controls and forwards requests to the bridge.
  final AgentDispatcher dispatcher;

  /// Names the transport, matching [AgentDispatcher.transportName].
  String get name;

  /// Reports whether the transport is currently accepting requests.
  bool get isRunning;

  /// Stops accepting requests and releases the transport's resources.
  ///
  /// Stopping is idempotent: calling it on a stopped transport does nothing.
  /// It does **not** disable the bridge itself; call
  /// `AgentBridge.instance.configure(enabled: false)` for the global kill
  /// switch.
  Future<void> stop();

  /// Builds the dispatcher a transport should use and installs the auth gate.
  ///
  /// This is the single place where the secure-by-default policy is enforced,
  /// so every transport inherits it. Supplying [verifier] installs an
  /// [AgentTokenAuthorizer] on [bridge], **replacing any authorizer previously
  /// configured**; omitting it leaves the bridge's authorizer untouched.
  ///
  /// Throws an [ArgumentError] when [bridge] is not enabled, so a transport
  /// can never exist ahead of the kill switch — on the web in particular, the
  /// `window` binding is never installed by a build that did not opt in.
  ///
  /// Throws an [ArgumentError] when [AgentBridgeServerOptions.requireAuth] is
  /// `true`, no [verifier] was supplied, and the bridge still carries the
  /// default [AgentAllowAllAuthorizer] — which would otherwise expose an
  /// unauthenticated transport.
  static AgentDispatcher createDispatcher({
    required AgentBridge bridge,
    required AgentBridgeServerOptions options,
    required String transportName,
    AgentTokenVerifier? verifier,
    AgentPrincipalResolver? principals,
    AgentAuditSink? auditSink,
    AgentAuditRedactor redactor = const AgentAuditRedactor(),
    bool requireAuthenticationForDiscovery = true,
  }) {
    var resolver = principals;
    if (resolver == null && verifier != null) {
      resolver = AgentPrincipalResolver(verifier: verifier);
    }
    if (!bridge.enabled) {
      throw ArgumentError(
        'The agent bridge transport refuses to start while the bridge is '
        'disabled. Call AgentBridge.configure(enabled: true) first, so the '
        'kill switch is always the single thing that decides whether a '
        'control surface exists at all.',
      );
    }
    if (resolver != null) {
      bridge.configure(
        authorizer: AgentTokenAuthorizer(
          principals: resolver,
          requireAuthenticationForDiscovery: requireAuthenticationForDiscovery,
        ),
        registerBuiltInCommands: false,
      );
    } else if (options.requireAuth &&
        bridge.authorizer is AgentAllowAllAuthorizer) {
      throw ArgumentError(
        'The agent bridge transport refuses to start without authentication. '
        'Pass a verifier, configure your own AgentAuthorizer on the bridge, or '
        'set AgentBridgeServerOptions(requireAuth: false) for a trusted, '
        'in-process scenario.',
      );
    }
    return AgentDispatcher(
      bridge: bridge,
      principals: resolver,
      rateLimiter: AgentRateLimiter(
        maxRequests: options.maxRequestsPerWindow,
        window: options.rateLimitWindow,
      ),
      audit: AgentAuditLog(sink: auditSink),
      redactor: redactor,
      maxRequestBytes: options.maxRequestBytes,
      transportName: transportName,
    );
  }
}

/// Drives the bridge from inside the running isolate, without any networking.
///
/// This is the transport used by tests, by embedded automation, and by a host
/// that already owns its own channel (a platform channel, an MCP stdio server,
/// a Cloud Function callback) and only needs the safety controls and the audit
/// trail. It is also the reference implementation: a network transport does
/// nothing more than decode a frame and call [sendJson].
class AgentInProcessTransport extends AgentTransport {
  /// Creates an in-process transport around [dispatcher].
  ///
  /// Prefer [start], which applies [AgentBridgeServerOptions] and installs the
  /// authentication gate.
  AgentInProcessTransport({required super.dispatcher});

  /// Starts an in-process transport against [bridge].
  ///
  /// Mirrors `AgentBridgeServer.start` so a host can swap transports without
  /// changing its bootstrap. Nothing is bound and no port is opened, so
  /// [AgentBridgeServerOptions.host] and [AgentBridgeServerOptions.port] are
  /// ignored.
  static Future<AgentInProcessTransport> start({
    AgentBridgeServerOptions options = const AgentBridgeServerOptions(),
    AgentBridge? bridge,
    AgentTokenVerifier? verifier,
    AgentPrincipalResolver? principals,
    AgentAuditSink? auditSink,
    bool requireAuthenticationForDiscovery = true,
  }) async => AgentInProcessTransport(
    dispatcher: AgentTransport.createDispatcher(
      bridge: bridge ?? AgentBridge.instance,
      options: options,
      transportName: transportName,
      verifier: verifier,
      principals: principals,
      auditSink: auditSink,
      requireAuthenticationForDiscovery: requireAuthenticationForDiscovery,
    ),
  );

  /// Names this transport in audit records.
  static const String transportName = 'in_process';

  /// Tracks whether [stop] has been called.
  bool _running = true;

  /// Names the transport, always [transportName].
  @override
  String get name => transportName;

  /// Reports whether the transport still accepts requests.
  @override
  bool get isRunning => _running;

  /// Sends a decoded [request] map and returns the decoded response map.
  ///
  /// [connectionId] buckets the rate limit for unauthenticated callers and
  /// [token] supplies a credential when the envelope carries none. A request
  /// sent after [stop] answers with [AgentErrorCode.disabled] instead of
  /// reaching the bridge.
  Future<Map<String, dynamic>> send(
    Map<String, dynamic>? request, {
    String? connectionId,
    String? token,
  }) async {
    if (!_running) return _stopped(request);
    return dispatcher.handle(request, connectionId: connectionId, token: token);
  }

  /// Sends an encoded JSON [payload] and returns the encoded response.
  ///
  /// Malformed JSON produces an `invalid_params` error response rather than
  /// throwing, exactly as it does on a network transport.
  Future<String> sendJson(
    String payload, {
    String? connectionId,
    String? token,
  }) async {
    if (!_running) return jsonEncode(_stopped(null));
    return dispatcher.handleJson(
      payload,
      connectionId: connectionId,
      token: token,
    );
  }

  /// Builds the response returned once the transport has been stopped.
  Map<String, dynamic> _stopped(Map<String, dynamic>? request) {
    final id = request?['id'];
    return AgentResponse.failure(
      id: id is String ? id : '',
      error: AgentError(
        code: AgentErrorCode.disabled,
        message: 'The in-process agent transport has been stopped.',
      ),
    ).toJson();
  }

  /// Stops accepting requests.
  @override
  Future<void> stop() async {
    _running = false;
  }
}
