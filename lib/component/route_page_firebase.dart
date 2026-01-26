import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/notification_data.dart';
import '../state/state_notifications.dart';
import 'alert_data.dart';
import 'route_page.dart';

/// RoutePageFirebase
/// Use to wrap
/// Extends [BaseRoutePage]
class RoutePageFirebase extends BaseRoutePage {
  const RoutePageFirebase({
    super.key,
    required super.routeHelper,
    required super.uri,
    required super.status,
    super.loading = const LoadingScreen(),
    super.onInit,
  });

  @override
  State<BaseRoutePage> createState() => _RoutePageNotificationsState();
}

class _RoutePageNotificationsState extends BaseRoutePageState {
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);

    /// Assign notification callback
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

    /// Return the parent build method
    return super.build(context);
  }
}
