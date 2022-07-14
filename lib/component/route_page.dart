library fabric_flutter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/route_helper.dart';
import '../serialized/user_data.dart';
import '../state/state_alert.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({
    Key? key,
    required this.routeHelper,
    required this.uri,
    required this.stream,
    required this.status,
  }) : super(key: key);
  final RouteHelper routeHelper;
  final Uri uri;
  final Stream<UserStatus> stream;
  final UserStatus status;

  @override
  Widget build(BuildContext context) {
    final stateAlert = Provider.of<StateAlert>(context, listen: false);
    stateAlert.context = context;
    return StreamBuilder<dynamic>(
      initialData: status,
      stream: stream,
      builder: (context, snapshot) {
        UserStatus userStatus = snapshot.data as UserStatus;
        Map<String, Widget> routes = routeHelper.routes(
          signed: userStatus.signedIn,
          isAdmin: userStatus.admin,
        );
        if (routes.containsKey(uri.path)) {
          return routes[uri.path]!;
        }
        return routes[routeHelper.unknownRoute]!;
      },
    );
  }
}
