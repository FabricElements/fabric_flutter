import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_global.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../helper/route_helper.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/notification_data.dart';
import '../serialized/user_status.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import 'alert_data.dart';

bool _listenersConfigured = false;

/// Configure global listeners for connectivity and notifications
void _configureListeners(BuildContext context) {
  if (_listenersConfigured) return;
  final locales = AppLocalizations.of(context);
  final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
  final stateNotifications = Provider.of<StateNotifications>(
    context,
    listen: false,
  );

  /// Show connectivity alerts
  stateGlobal.streamConnection.listen((connected) {
    final BuildContext safeContext =
        AppGlobal.navigatorKey.currentContext ?? context;
    if (connected) {
      alertData(
        context: safeContext,
        icon: Icons.wifi,
        body: locales.get('notification--you-are-back-online'),
        duration: 2,
      );
    } else {
      final BuildContext safeContext =
          AppGlobal.navigatorKey.currentContext ?? context;
      alertData(
        context: safeContext,
        icon: Icons.wifi_off,
        body: locales.get('notification--you-are--offline'),
        duration: 100,
        type: AlertType.warning,
      );
    }
  });

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
    this.loading = const LoadingScreen(),
    required this.onInit,
    required this.onContextReady,
  });

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  late final Future<void> _future;

  @override
  void initState() {
    super.initState();
    // Create the future once so rebuilds don't restart it.
    _future = _initFuture(widget.onInit);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    widget.onContextReady(context);

    return FutureBuilder<void>(
      future: _future,
      builder: (BuildContext ctx, AsyncSnapshot<void> snapshot) {
        final notReady = status == null || !status.ready;
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.active:
          case ConnectionState.waiting:
            return widget.loading;
          default:
        }
        if (notReady) return widget.loading;
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
          onTap: () {
            /// Close keyboard when tap outside input
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.requestFocus(FocusNode());
            }
          },
          child: routeWidget,
        );
      },
    );
  }
}
