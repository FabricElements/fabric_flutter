import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/route_helper.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/notification_data.dart';
import '../serialized/user_status.dart';
import '../state/state_notifications.dart';
import 'alert_data.dart';
import 'connection_status.dart';

/// Stores the guard flag consulted before listener configuration runs.
bool _listenersConfigured = false;

/// Configures notification listeners for the current route context.
///
/// The method checks [_listenersConfigured] before wiring the callback so the
/// route can centralize notification alerts around a single [BuildContext].
void _configureListeners(BuildContext context) {
  if (_listenersConfigured) return;
  final locales = AppLocalizations.of(context);
  final stateNotifications = Provider.of<StateNotifications>(
    context,
    listen: false,
  );

  stateNotifications.callback = (NotificationData message) {
    alertData(
      context: context,
      duration: message.duration,
      title: message.title,
      body: message.body,
      image: message.imageUrl,
      typeString: message.type,
      clear: message.clear,
      action: (message.path != null)
          ? ButtonOptions(
              label: locales.get('label--open'),
              onTap: () {
                Navigator.of(context).popAndPushNamed(message.path!);
              },
            )
          : null,
    );
  };
}

/// Runs route initialization and preserves a consistent loading experience.
///
/// The wrapper catches and logs errors thrown by [onInit] so route rendering can
/// continue, then waits briefly before completing to avoid flashes when setup
/// resolves almost immediately.
Future<void> _initFuture(Future<void> Function() onInit) async {
  try {
    await onInit();
  } catch (e, st) {
    debugPrint(LogColor.error('$e\n$st'));
  }

  await Future<void>.delayed(const Duration(milliseconds: 300));
}

/// Builds a route wrapper that waits for asynchronous setup before showing content.
///
/// The widget resolves the active route from [routeHelper] and [uri], waits for
/// [status] and [onInit], and then renders the resulting child without restarting
/// initialization on every rebuild.
class RoutePage extends StatefulWidget {
  /// Creates a route wrapper that defers route content until setup completes.
  ///
  /// Callers provide the route table through [routeHelper], the current location
  /// through [uri], and any asynchronous bootstrap work through [onInit].
  const RoutePage({
    super.key,
    required this.routeHelper,
    required this.uri,
    required this.status,
    this.loading = const LoadingScreen(key: Key('route-page-loading')),
    required this.onInit,
    required this.onContextReady,
  });

  /// Stores the route resolver used to look up the widget for [uri].
  ///
  /// The helper supplies authenticated, unauthenticated, and fallback route
  /// entries after initialization finishes.
  final RouteHelper routeHelper;

  /// Stores the parsed location used to choose the current route widget.
  ///
  /// The [Uri.path] value is matched against the route map returned by
  /// [routeHelper].
  final Uri uri;

  /// Stores the latest authentication state required before initialization continues.
  ///
  /// The page keeps showing [loading] until [status] is not `null` and reports
  /// that it is ready.
  final UserStatus? status;

  /// Stores the placeholder displayed while the route is still resolving.
  ///
  /// The widget is shown while [status] is unavailable or while [onInit] has not
  /// completed.
  final Widget loading;

  /// Stores the one-time asynchronous setup callback for the route.
  ///
  /// The callback is wrapped by [_initFuture] so failures are logged and brief
  /// loading feedback is preserved.
  final Future<void> Function() onInit;

  /// Stores the callback that runs after the [BuildContext] is ready.
  ///
  /// Callers can use the callback to perform context-dependent work once
  /// [status] has finished resolving.
  final Function(BuildContext context) onContextReady;

  /// Creates the mutable state that caches route initialization across rebuilds.
  ///
  /// The returned [_RoutePageState] holds the single future used by the internal
  /// [FutureBuilder].
  @override
  State<RoutePage> createState() => _RoutePageState();
}

/// Builds the resolved route after cached initialization completes.
///
/// The state keeps asynchronous bootstrap work stable across rebuilds so route
/// changes caused by provider updates do not restart setup.
class _RoutePageState extends State<RoutePage> {
  /// Stores the cached initialization future for the current state instance.
  ///
  /// The future is created once in [initState] so rebuilds reuse the same async
  /// work.
  late final Future<void> _future;

  /// Stores whether the route is still considered loading.
  ///
  /// The field remains available for route-page state tracking even though the
  /// rendered loading UI is derived from [RoutePage.loading].
  bool loading = true;

  /// Initializes the cached future during the first lifecycle pass.
  ///
  /// Creating [_future] here ensures [RoutePage.onInit] does not restart when the
  /// widget rebuilds.
  @override
  void initState() {
    super.initState();
    _future = _initFuture(widget.onInit);
  }

  /// Builds loading or route content based on auth and initialization state.
  ///
  /// The method keeps showing [RoutePage.loading] until [RoutePage.status] is
  /// ready and [_future] completes, then configures listeners, resolves the route,
  /// and dismisses focus when users tap outside an input.
  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    if (status == null || !status.ready) {
      return widget.loading;
    }
    widget.onContextReady(context);
    return FutureBuilder<void>(
      key: ValueKey('route-page-future'),
      future: _future,
      builder: (BuildContext ctx, AsyncSnapshot<void> snapshot) {
        bool resolved = false;
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.active:
          case ConnectionState.waiting:
            resolved = false;
          default:
            resolved = true;
        }
        if (!resolved) return widget.loading;

        _configureListeners(context);

        final routes = widget.routeHelper.routes(
          signed: status.signedIn,
          isAdmin: status.admin,
        );
        late Widget routeWidget;
        if (routes.containsKey(widget.uri.path)) {
          routeWidget = routes[widget.uri.path]!;
        } else {
          routeWidget = routes[widget.routeHelper.unknownRoute]!;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          key: ValueKey('route-page-gesture-detector'),
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          },
          child: Stack(
            fit: StackFit.loose,
            children: [
              KeyedSubtree(
                key: ValueKey('route-page-child'),
                child: routeWidget,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: const ConnectionStatus(),
              ),
            ],
          ),
        );
      },
    );
  }
}
