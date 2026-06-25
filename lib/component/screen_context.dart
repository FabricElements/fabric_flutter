import 'package:flutter/material.dart';

/// Wraps a screen's widget tree with a semantic container that identifies the active route.
///
/// [ScreenContext] is a non-visual widget that injects a deterministic [Semantics]
/// node at the root of each view. Autonomous agents and automated test runners can
/// read the route name from the accessibility tree without relying on visual title
/// text, making navigation verification reliable and screen-independent.
///
/// Place [ScreenContext] at the outermost level of each route widget, or integrate
/// it directly into the [RoutePage] scaffold to apply it automatically across all
/// views.
///
/// ```dart
/// ScreenContext(
///   child: MyDashboardView(),
/// )
/// ```
///
/// The identifier in the semantics tree follows the format `screen_<routeName>`,
/// for example `screen_/dashboard` or `screen_/profile`.
class ScreenContext extends StatelessWidget {
  /// Creates a [ScreenContext] that wraps [child] with a route-scoped semantic container.
  ///
  /// Provide [routeName] to hard-code the semantic identifier, or omit it to
  /// derive the value from [ModalRoute.of] at build time.
  const ScreenContext({
    super.key,
    required this.child,
    this.routeName,
  });

  /// The widget subtree to annotate with the route-scoped semantic container.
  final Widget child;

  /// Overrides the route name used to build the semantic identifier.
  ///
  /// When `null`, falls back to the name reported by [ModalRoute.of].
  /// The final identifier becomes `screen_<routeName>`.
  final String? routeName;

  /// Builds the [Semantics] container and injects the resolved route identifier.
  ///
  /// Uses [routeName] when provided; otherwise reads [ModalRoute.settings.name]
  /// from the ambient [BuildContext]. When neither value is available, the
  /// [Semantics.identifier] is left unset.
  @override
  Widget build(BuildContext context) {
    final route = routeName ?? ModalRoute.of(context)?.settings.name;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: route != null ? 'screen_$route' : null,
      child: child,
    );
  }
}
