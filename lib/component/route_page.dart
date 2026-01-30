import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// RoutePage
/// A convenience widget that waits for an async `onInit` to finish
/// before rendering the route content. It extends FutureBuilder<void> so callers
/// don't need to wrap it in an extra FutureBuilder.
///
/// Note: the provided `onInit` is required and will be executed immediately
/// when the widget is constructed (the FutureBuilder's future runs at build
/// time). Because the callback runs without a guaranteed mounted BuildContext,
/// avoid invoking context-dependent APIs inside `onInit` (use a StatefulWidget
/// initState for logic that needs context or to interact with the widget tree).
class RoutePage extends FutureBuilder<void> {
  RoutePage({
    super.key,
    required RouteHelper routeHelper,
    required Uri uri,
    required UserStatus? status,
    Widget loading = const LoadingScreen(),
    required Future<void> Function() onInit,
  }) : super(
         initialData: status,
         // Build an async future that runs onInit, logs errors with
         // stacktrace, and waits a short delay before completing.
         future: _initFuture(onInit),
         builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
           if (snapshot.connectionState != ConnectionState.done) {
             return loading;
           }
           final notReady = status == null || !status.ready;
           if (notReady) return loading;
           final locales = AppLocalizations.of(context);
           final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
           final stateNotifications = Provider.of<StateNotifications>(
             context,
             listen: false,
           );

           /// Show connectivity alerts
           stateGlobal.streamConnection.listen((connected) {
             if (connected) {
               alertData(
                 context: context,
                 icon: Icons.wifi,
                 body: locales.get('notification--you-are-back-online'),
                 duration: 2,
               );
             } else {
               alertData(
                 context: context,
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

           /// Build the route map based on user status
           Map<String, Widget> routes = routeHelper.routes(
             signed: status.signedIn,
             isAdmin: status.admin,
           );
           if (routes.containsKey(uri.path)) {
             return routes[uri.path]!;
           }
           return routes[routeHelper.unknownRoute]!;
         },
       );

  /// This helper runs the provided `onInit` function, logs any errors,
  /// and adds a small delay to ensure a consistent loading experience.
  static Future<void> _initFuture(Future<void> Function() onInit) async {
    try {
      await onInit();
    } catch (e, st) {
      debugPrint(LogColor.error('$e\n$st'));
    }

    // Small delay to keep a consistent loading experience.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
