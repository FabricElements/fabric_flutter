import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/route_helper.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/user_status.dart';
import '../state/state_alert.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({
    super.key,
    required this.routeHelper,
    required this.uri,
    required this.status,
    this.loading = const LoadingScreen(),
  });

  final RouteHelper routeHelper;
  final Uri uri;
  final UserStatus? status;
  final Widget loading;

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  @override
  void didUpdateWidget(covariant RoutePage oldWidget) {
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == null) return widget.loading;
    final locales = AppLocalizations.of(context);
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
