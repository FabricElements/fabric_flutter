/// Exports the platform-specific minimal iframe implementation.
///
/// Widgets such as `GoogleChart` depend on this conditional export so the same
/// API can embed HTML content on the web while providing a native-compatible
/// implementation elsewhere.
library;

export 'iframe_minimal_native.dart'
    if (dart.library.html) 'iframe_minimal_web.dart';
