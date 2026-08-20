import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../log_color.dart';
import 'agent_audit.dart';
import 'agent_bridge.dart';
import 'agent_bridge_server_options.dart';
import 'agent_principal_resolver.dart';
import 'agent_token_authorizer.dart';
import 'agent_transport.dart';

/// Exposes the agent bridge over a loopback socket on native platforms.
///
/// The server speaks two interchangeable framings on one port so an agent can
/// use whichever its client library supports:
///
/// * **WebSocket** (`ws://127.0.0.1:8757/`) — each text frame is one JSON
///   request and each reply is one JSON response, which suits a long-lived
///   agent session that polls `state` and waits on `wait_for`.
/// * **HTTP** (`POST http://127.0.0.1:8757/`) — the request body is one JSON
///   request and the response body is the JSON response, which suits a
///   one-shot script or a curl-style probe.
///
/// It is **secure by default**: it binds the loopback interface only, refuses
/// to start without an authentication gate, caps request size and concurrent
/// connections, and rate limits every caller. It never enables the bridge — the
/// global kill switch stays with `AgentBridge.configure(enabled: ...)`, and a
/// disabled bridge answers every request with the `disabled` error even while
/// the socket is open.
///
/// ```dart
/// final server = await AgentBridgeServer.start(
///   bridge: AgentBridge.instance,
///   verifier: (token) => myBackend.principalFor(token),
/// );
/// debugPrint('agent bridge on ${server.uri}');
/// await server.stop();
/// ```
class AgentBridgeServer extends AgentTransport {
  /// Creates a server around an already bound [httpServer].
  ///
  /// Use [start]; this constructor exists so the class stays testable.
  AgentBridgeServer({
    required super.dispatcher,
    required HttpServer httpServer,
    required this.options,
  }) : _server = httpServer,
       host = httpServer.address.address,
       port = httpServer.port {
    _subscription = _server.listen(
      _handleHttpRequest,
      onError: _reportError,
      cancelOnError: false,
    );
  }

  /// Starts a loopback server in front of [bridge].
  ///
  /// Supplying [verifier] installs an [AgentTokenAuthorizer] on the bridge,
  /// replacing any authorizer previously configured. When it is omitted and
  /// [AgentBridgeServerOptions.requireAuth] is `true`, starting throws an
  /// [ArgumentError] unless the host already installed its own authorizer.
  /// [auditSink] receives one record per `invoke`.
  ///
  /// Binding failures — a port already in use, a denied permission — surface as
  /// the underlying [SocketException].
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
    final httpServer = await HttpServer.bind(options.host, options.port);
    return AgentBridgeServer(
      dispatcher: dispatcher,
      httpServer: httpServer,
      options: options,
    );
  }

  /// Names this transport in audit records.
  static const String transportName = 'socket';

  /// Configures the bound address, limits, and authentication policy.
  final AgentBridgeServerOptions options;

  /// Accepts incoming connections.
  final HttpServer _server;

  /// Tracks the request listener so it can be cancelled on [stop].
  late final StreamSubscription<HttpRequest> _subscription;

  /// Holds every open WebSocket so [stop] can close them.
  final Set<WebSocket> _sockets = <WebSocket>{};

  /// Counts in-flight HTTP requests and open sockets against the limit.
  int _connections = 0;

  /// Numbers connections so each gets a distinct rate-limit bucket.
  int _connectionSequence = 0;

  /// Tracks whether the server is still listening.
  bool _running = true;

  /// Names the transport, always [transportName].
  @override
  String get name => transportName;

  /// Reports whether the socket is still open.
  @override
  bool get isRunning => _running;

  /// Names the address the server is bound to.
  ///
  /// Captured at bind time so it stays readable after [stop].
  final String host;

  /// Sets the port the server listens on.
  ///
  /// When [AgentBridgeServerOptions.port] was `0` this is the ephemeral port
  /// the operating system chose. Captured at bind time so it stays readable
  /// after [stop].
  final int port;

  /// Returns the WebSocket endpoint agents connect to.
  Uri get uri => Uri(scheme: 'ws', host: host, port: port, path: '/');

  /// Returns the number of connections currently counted against the limit.
  int get connections => _connections;

  /// Closes every open connection and stops listening.
  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _subscription.cancel();
    for (final socket in _sockets.toList()) {
      await socket.close(WebSocketStatus.goingAway, 'stopped');
    }
    _sockets.clear();
    _connections = 0;
    await _server.close(force: true);
  }

  /// Routes an incoming [request] to the WebSocket or HTTP handler.
  Future<void> _handleHttpRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      await _handleUpgrade(request);
      return;
    }
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    await _handlePost(request);
  }

  /// Upgrades [request] to a WebSocket and serves requests until it closes.
  Future<void> _handleUpgrade(HttpRequest request) async {
    if (_connections >= options.maxConnections) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.write('Too many agent bridge connections.');
      await request.response.close();
      return;
    }
    final token = _tokenFrom(request);
    final connectionId = 'ws-${_connectionSequence++}';
    final socket = await WebSocketTransformer.upgrade(request);
    _connections++;
    _sockets.add(socket);
    socket.listen(
      (Object? frame) async {
        final payload = frame is String
            ? frame
            : frame is List<int>
            ? _decodeBinary(frame)
            : '';
        final response = await dispatcher.handleJson(
          payload,
          connectionId: connectionId,
          token: token,
        );
        if (socket.readyState == WebSocket.open) socket.add(response);
      },
      onError: _reportError,
      onDone: () {
        _sockets.remove(socket);
        if (_connections > 0) _connections--;
      },
      cancelOnError: false,
    );
  }

  /// Serves a single JSON request carried in the body of [request].
  Future<void> _handlePost(HttpRequest request) async {
    if (_connections >= options.maxConnections) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }
    _connections++;
    try {
      final declared = request.contentLength;
      if (declared > options.maxRequestBytes) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        await request.response.close();
        return;
      }
      final body = await _readBody(request);
      if (body == null) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        await request.response.close();
        return;
      }
      final response = await dispatcher.handleJson(
        body,
        connectionId: 'http-${_connectionSequence++}',
        token: _tokenFrom(request),
      );
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(response);
      await request.response.close();
    } catch (error) {
      _reportError(error);
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    } finally {
      if (_connections > 0) _connections--;
    }
  }

  /// Reads the body of [request], or returns `null` when it exceeds the cap.
  ///
  /// The body is accumulated chunk by chunk and abandoned as soon as the limit
  /// is passed, so an unbounded or mis-declared upload never lands in memory.
  Future<String?> _readBody(HttpRequest request) async {
    final chunks = <int>[];
    await for (final chunk in request) {
      chunks.addAll(chunk);
      if (chunks.length > options.maxRequestBytes) return null;
    }
    return utf8.decode(chunks, allowMalformed: true);
  }

  /// Returns the bearer token carried by [request], or `null` when absent.
  ///
  /// The `Authorization` header is preferred; a `token` query parameter is
  /// accepted as a fallback because browser WebSocket clients cannot set
  /// headers on the handshake. Either way the value is normalized and injected
  /// into the reserved `auth` request parameter by the dispatcher, so the
  /// authorizer sees one uniform token location.
  String? _tokenFrom(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    final query = request.uri.queryParameters['token'];
    return AgentPrincipalResolver.normalizeToken(header) ??
        AgentPrincipalResolver.normalizeToken(query);
  }

  /// Decodes a binary WebSocket [frame] as UTF-8 text.
  String _decodeBinary(List<int> frame) =>
      utf8.decode(frame, allowMalformed: true);

  /// Reports a transport failure without letting it reach the caller.
  void _reportError(Object error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint(LogColor.error('Agent bridge transport error: $error'));
    }
  }
}
