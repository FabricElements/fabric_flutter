/// Exports the platform-specific agent bridge server implementation.
///
/// The transport that can expose the bridge differs fundamentally by platform:
/// on Android, iOS, macOS, Windows, and Linux it is a loopback socket server,
/// while on the web a socket cannot be opened at all and the bridge is instead
/// published as a callable JavaScript entry point that a browser-driving agent
/// (Playwright, CDP, an extension) can invoke. This conditional export selects
/// the web implementation when `dart:js_interop` is available so consumers use
/// [AgentBridgeServer] without branching on the platform themselves.
library;

export 'agent_bridge_server_native.dart'
    if (dart.library.js_interop) 'agent_bridge_server_web.dart';
