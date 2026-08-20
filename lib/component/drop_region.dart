/// Exports the platform-specific drop region implementation.
///
/// External file drag-and-drop is only meaningful on the web, so this conditional
/// export selects the web implementation when `dart:js_interop` is available and
/// falls back to a no-op region on Android and iOS. Consumers import this file
/// and use [DropRegion] without branching on the platform themselves.
library;

export 'drop_region_native.dart'
    if (dart.library.js_interop) 'drop_region_web.dart';
