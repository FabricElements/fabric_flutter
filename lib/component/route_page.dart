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

/// Tracks whether global connectivity and notification listeners are already attached.
bool _listenersConfigured = false;

/// Configures global notification listeners exactly once for the current app session.
///
/// Route pages rebuild frequently as authentication and navigation state change,
/// so this guard prevents duplicate callbacks from stacking up across rebuilds.
void _configureListeners(BuildContext context) {
  if (_listenersConfigured) return;
  final locales = AppLocalizations.of(context);
  final stateNotifications = Provider.of<StateNotifications>(
    context,
    listen: false,
  );

  /// Define notification callback
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

/// This helper runs the provided `onInit` function, logs any errors,
/// and adds a small delay to ensure a consistent loading experience.
Future<void> _initFuture(Future<void> Function() onInit) async {
  try {
    await onInit();
  } catch (e, st) {
    debugPrint(LogColor.error('$e\n$st'));
  }

  // Small delay to keep a consistent loading experience.
  await Future<void>.delayed(const Duration(milliseconds: 300));
}

/// RoutePage
/// A convenience widget that waits for an async `onInit` to finish
/// before rendering the route content. It used to extend FutureBuilder<void>,
/// but now creates the future once in state so rebuilds won't restart it.
class RoutePage extends StatefulWidget {
  /// Creates a route wrapper that waits for initialization before showing content.
  ///
  /// Use this when a route depends on async setup, such as fetching data or
  /// attaching listeners, but should avoid restarting that work on every rebuild.
  const RoutePage({
    super.key,
    required this.routeHelper,
    required this.uri,
    required this.status,
    this.loading = const LoadingScreen(key: Key('route-page-loading')),
    required this.onInit,
    required this.onContextReady,
  });

  /// Provides the route table used to resolve the widget for [uri].
  final RouteHelper routeHelper;
  /// The parsed location used to choose the current route widget.
  final Uri uri;

  /// The latest authentication status required before route initialization can continue.
  final UserStatus? status;

  /// The placeholder displayed while auth state or [onInit] is unresolved.
  final Widget loading;

  /// Performs one-time asynchronous initialization for the route.
  final Future<void> Function() onInit;

  /// Runs after user status is ready so callers can access an initialized [BuildContext].
  final Function(BuildContext context) onContextReady;

  /// Creates the mutable state that caches the initialization future across rebuilds.
  @override
  State<RoutePage> createState() => _RoutePageState();
}

/// Holds the cached initialization future and builds the resolved route content.
class _RoutePageState extends State<RoutePage> {
  /// Caches the async initialization work so it runs only once per state instance.
  late final Future<void> _future;

  /// Tracks whether the route is still showing its loading affordance.
  bool loading = true;

  /// Creates the initialization future during the first lifecycle pass.
  @override
  void initState() {
    super.initState();
    // Create the future once so rebuilds don't restart it.
    _future = _initFuture(widget.onInit);
  }

  /// Resolves auth state, waits for initialization, and then builds the current route.
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

        /// Configure global listeners
        _configureListeners(context);

        /// Get routes
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

        /// Return child with KeyedSubtree to avoid rebuild issues
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          key: ValueKey('route-page-gesture-detector'),
          onTap: () {
            /// Close keyboard when tap outside input
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
