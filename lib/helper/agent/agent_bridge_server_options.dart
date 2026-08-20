import '../../serialized/agent_error.dart';

/// Configures how an agent bridge transport is exposed.
///
/// The defaults are deliberately restrictive: the server binds to the loopback
/// interface only, accepts a handful of concurrent connections, caps request
/// size, rate limits every caller, and refuses to start without an
/// authentication verifier. Loosening any of these is an explicit, auditable
/// decision at the call site.
class AgentBridgeServerOptions {
  /// Creates transport options, overriding only what differs from the defaults.
  const AgentBridgeServerOptions({
    this.host = defaultHost,
    this.port = defaultPort,
    this.maxRequestBytes = 64 * 1024,
    this.maxConnections = 4,
    this.maxRequestsPerWindow = 60,
    this.rateLimitWindow = const Duration(minutes: 1),
    this.requireAuth = true,
    this.jsBindingName = defaultJsBindingName,
  }) : assert(port >= 0 && port <= 65535, 'port must be a valid TCP port'),
       assert(maxRequestBytes > 0, 'maxRequestBytes must be positive'),
       assert(maxConnections > 0, 'maxConnections must be positive');

  /// Binds the loopback interface, which is the only safe default.
  ///
  /// An agent running on the same machine — an MCP server, a test harness, a
  /// desktop automation client — reaches the app here, while nothing on the
  /// local network can.
  static const String defaultHost = '127.0.0.1';

  /// Sets the default TCP port; pass `0` to let the operating system pick one.
  static const int defaultPort = 8757;

  /// Names the default JavaScript entry point installed on the web.
  static const String defaultJsBindingName = 'fabricAgentBridge';

  /// Names the network interface the native server binds to.
  ///
  /// Changing this away from [defaultHost] exposes the bridge beyond the
  /// device and must be paired with a real authentication verifier.
  final String host;

  /// Sets the TCP port the native server listens on.
  final int port;

  /// Bounds the size in bytes of a single encoded request.
  ///
  /// A larger frame is answered with [AgentErrorCode.invalidParams] and is
  /// never decoded, which keeps a hostile client from exhausting memory.
  final int maxRequestBytes;

  /// Bounds how many transport connections may be open at once.
  ///
  /// A connection beyond the limit is rejected immediately, so a client that
  /// leaks sockets cannot starve the application.
  final int maxConnections;

  /// Bounds how many requests one caller may issue per [rateLimitWindow].
  final int maxRequestsPerWindow;

  /// Sets the sliding window the request count is measured over.
  final Duration rateLimitWindow;

  /// Requires an authentication gate before the transport starts.
  ///
  /// When `true`, starting a transport throws an [ArgumentError] unless a
  /// verifier is supplied or the bridge already carries a non-default
  /// authorizer. Set it to `false` only for a trusted, in-process, developer
  /// scenario.
  final bool requireAuth;

  /// Names the property installed on `window` by the web transport.
  final String jsBindingName;

  /// Returns a copy of these options with the supplied overrides applied.
  AgentBridgeServerOptions copyWith({
    String? host,
    int? port,
    int? maxRequestBytes,
    int? maxConnections,
    int? maxRequestsPerWindow,
    Duration? rateLimitWindow,
    bool? requireAuth,
    String? jsBindingName,
  }) => AgentBridgeServerOptions(
    host: host ?? this.host,
    port: port ?? this.port,
    maxRequestBytes: maxRequestBytes ?? this.maxRequestBytes,
    maxConnections: maxConnections ?? this.maxConnections,
    maxRequestsPerWindow: maxRequestsPerWindow ?? this.maxRequestsPerWindow,
    rateLimitWindow: rateLimitWindow ?? this.rateLimitWindow,
    requireAuth: requireAuth ?? this.requireAuth,
    jsBindingName: jsBindingName ?? this.jsBindingName,
  );
}
