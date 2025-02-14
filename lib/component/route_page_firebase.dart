import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_alert.dart';
import '../state/state_notifications.dart';
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
    final alert = Provider.of<StateAlert>(context, listen: false);
    alert.context = context;

    /// Assign notification callback
    final stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    stateNotifications.callback = (Map<String, dynamic> message) {
      int duration = 5;
      String? path = message['path']?.trim();
      if (path?.isEmpty ?? true) {
        path = null;
      } else {
        duration = 10;
      }
      // Translate title
      String? title = message['title'];
      if (title != null && title.isNotEmpty) {
        title = locales.get(title);
      } else {
        title = null;
      }
      // Translate body
      String? body = message['body'];
      if (body != null && body.isNotEmpty) {
        body = locales.get(body);
      } else {
        body = null;
      }
      alert.show(AlertData(
        duration: duration,
        title: title,
        body: body,
        image: message['imageUrl'],
        typeString: message['type'],
        clear: message['clear'] ?? false,
        action: (path != null)
            ? ButtonOptions(
                label: locales.get('label--open'),
                onTap: () {
                  Navigator.of(alert.context ?? context).popAndPushNamed(path!);
                },
              )
            : null,
      ));
    };

    /// Return the parent build method
    return super.build(context);
  }
}
