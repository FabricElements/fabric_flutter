import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_alert.dart';
import '../state/state_notifications.dart';
import 'route_page.dart';

class RoutePageFirebase extends RoutePage {
  const RoutePageFirebase({
    super.key,
    required super.routeHelper,
    required super.uri,
    required super.status,
    super.loading = const LoadingScreen(),
  });

  @override
  State<RoutePageFirebase> createState() => _RoutePageNotificationsState();
}

class _RoutePageNotificationsState extends State<RoutePageFirebase> {
  @override
  Widget build(BuildContext context) {
    if (widget.status == null) return widget.loading;
    final locales = AppLocalizations.of(context)!;
    final alert = Provider.of<StateAlert>(context, listen: false);
    alert.context = context;
    try {
      if (widget.status?.connectionChanged ?? false) {
        if (widget.status?.connected ?? false) {
          alert.show(AlertData(
            icon: Icons.wifi,
            body: locales.get('notification--you-are-back-online'),
            clear: true,
            duration: 2,
          ));
        } else {
          alert.show(AlertData(
            icon: Icons.wifi_off,
            body: locales.get('notification--you-are--offline'),
            clear: true,
            duration: 2,
            type: AlertType.warning,
          ));
        }
      }
    } catch (e) {
      //
    }

    /// Assign notification callback
    final stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    stateNotifications.callback = (Map<String, dynamic> message) {
      int duration = 5;
      String? path = message['path'];
      String? origin = message['origin'];
      if (path != null) {
        duration = 10;
      } else {
        path = null;
      }
      if (origin == 'resume' && path != null) {
        Navigator.of(context).popAndPushNamed(path);
        path = null;
      }
      return alert.show(AlertData(
        duration: duration,
        title: message['title'],
        body: message['body'],
        image: message['imageUrl'],
        typeString: message['type'],
        clear: message['clear'] ?? false,
        action: (path != null)
            ? ButtonOptions(
                label: locales.get('label--open'),
                onTap: () {
                  Navigator.of(context).popAndPushNamed(path!);
                },
              )
            : null,
      ));
    };

    if (widget.status?.signedIn ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await stateNotifications.getUserToken();
        } catch (error) {
          debugPrint('StateNotifications.getUserToken() Error: $error');
        }
      });
    }

    Map<String, Widget> routes = widget.routeHelper.routes(
      signed: widget.status!.signedIn,
      isAdmin: widget.status!.admin,
    );
    if (routes.containsKey(widget.uri.path)) {
      return routes[widget.uri.path]!;
    }
    return routes[widget.routeHelper.unknownRoute]!;
  }
}
