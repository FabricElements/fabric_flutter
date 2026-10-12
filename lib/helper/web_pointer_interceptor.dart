import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Stops pointer events from reaching web platform views beneath [child].
///
/// On the web, HTML elements such as maps and iframes sit above Flutter's
/// canvas and swallow taps aimed at Flutter overlays, so the child is wrapped in
/// a [PointerInterceptor]. On iOS and Android that plugin inserts a native view
/// behind the child, and that native layer can paint above Flutter overlays such
/// as menus. Native platforms have no such layer to intercept, so [child] is
/// returned unchanged there.
class WebPointerInterceptor extends StatelessWidget {
  /// Creates a web-only pointer interceptor around [child].
  const WebPointerInterceptor({super.key, required this.child});

  /// The widget that receives pointer events on the web.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return PointerInterceptor(child: child);
  }
}
