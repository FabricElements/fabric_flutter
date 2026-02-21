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

bool _listenersConfigured = false;

/// Configure global listeners for connectivity and notifications
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
  final RouteHelper routeHelper;
  final Uri uri;
  final UserStatus? status;
  final Widget loading;
  final Future<void> Function() onInit;
  final Function(BuildContext context) onContextReady;

  const RoutePage({
    super.key,
    required this.routeHelper,
    required this.uri,
    required this.status,
    this.loading = const LoadingScreen(key: Key('route-page-loading')),
    required this.onInit,
    required this.onContextReady,
  });

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  late final Future<void> _future;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    // Create the future once so rebuilds don't restart it.
    _future = _initFuture(widget.onInit);
  }

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
				  behavior: HitTestBehavior.opaque, // Ensures taps outside hit your detector.
				  key: ValueKey('route-page-gesture-detector'),
				  onTap: () {
				    /// Close keyboard when tap outside input
				    FocusScopeNode currentFocus = FocusScope.of(context);
				    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
				      currentFocus.focusedChild.unfocus(); // Explicitly unfocus.
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
