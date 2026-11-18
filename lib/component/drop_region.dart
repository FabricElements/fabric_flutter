/// Exports the platform-specific drop region implementation.
///
/// The two implementations wire different drag-and-drop sources — browser events
/// on the web, the platform drag interaction elsewhere — behind one API, so this
/// conditional export selects the web implementation when `dart:js_interop` is
/// available and the native one otherwise. Consumers import this file and use
/// [DropRegion] without branching on the platform themselves.
library;

export 'drop_region_native.dart'
    if (dart.library.js_interop) 'drop_region_web.dart';
