import 'package:flutter/widgets.dart';

import '../app_global.dart';

/// Tracks the route the application is currently showing.
///
/// Attach it to `MaterialApp.navigatorObservers` so the bridge can report the
/// active route without walking the widget tree:
///
/// ```dart
/// MaterialApp(
///   navigatorKey: AppGlobal.navigatorKey,
///   navigatorObservers: [AgentNavigatorObserver.instance],
/// );
/// ```
///
/// When the observer is not attached, the bridge falls back to reading the
/// ambient [ModalRoute] through [AppGlobal.navigatorKey].
class AgentNavigatorObserver extends NavigatorObserver {
  /// Creates an observer that records the active route.
  ///
  /// Prefer [instance] so the bridge and the host share one observer.
  AgentNavigatorObserver();

  /// Provides the shared observer read by the bridge.
  static final AgentNavigatorObserver instance = AgentNavigatorObserver();

  /// Holds the most recently reported route settings.
  RouteSettings? _current;

  /// Returns the active route name, or `null` when it is unknown.
  ///
  /// Falls back to the ambient [ModalRoute] when this observer has not been
  /// attached to a navigator.
  String? get routeName => _current?.name ?? _fallbackSettings()?.name;

  /// Returns the arguments the active route was pushed with.
  ///
  /// Returns an empty map when the route carries no arguments or when they are
  /// not expressed as a map.
  Map<String, dynamic> get routeParams {
    final arguments = _current?.arguments ?? _fallbackSettings()?.arguments;
    if (arguments is Map) {
      return arguments.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  /// Clears the recorded route.
  ///
  /// Intended for tests that reuse the shared [instance].
  void reset() => _current = null;

  /// Reads the route settings from the global navigator, when available.
  RouteSettings? _fallbackSettings() {
    final context = AppGlobal.navigatorKey.currentContext;
    if (context == null) return null;
    return ModalRoute.of(context)?.settings;
  }

  /// Records the pushed route as the active one.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _current = route.settings;
  }

  /// Restores the previous route as the active one after a pop.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _current = previousRoute?.settings;
  }

  /// Restores the previous route as the active one after a removal.
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _current = previousRoute?.settings;
  }

  /// Records the replacement route as the active one.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _current = newRoute.settings;
  }
}
