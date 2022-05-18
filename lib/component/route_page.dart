import 'package:fabric_flutter/helper/route_helper.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state_alert.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({Key? key, required this.routeHelper, required this.uri})
      : super(key: key);
  final RouteHelper routeHelper;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final stateUser = Provider.of<StateUser>(context, listen: false);
    final stateAlert = Provider.of<StateAlert>(context, listen: false);
    stateAlert.context = context;
    stateAlert.mounted = true;
    return StreamBuilder<User?>(
      stream: stateUser.streamUser,
      builder: (context, snapshot) {
        Widget page = Container(color: Colors.green.shade500);
        Map<String, Widget> _routes = routeHelper.routes(
          signed: stateUser.signedIn,
          isAdmin: stateUser.admin,
        );
        if (_routes.containsKey(uri.path)) {
          page = _routes[uri.path]!;
          return page;
        }
        return _routes[routeHelper.unknownRoute]!;
      },
    );
  }
}
