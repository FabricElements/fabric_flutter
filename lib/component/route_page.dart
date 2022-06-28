import 'package:fabric_flutter/helper/route_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final Stream<UserStatus?> stream;
  final UserStatus status;

  @override
  Widget build(BuildContext context) {
    final stateAlert = Provider.of<StateAlert>(context, listen: false);
    stateAlert.context = context;
    return StreamBuilder<dynamic>(
      initialData: status,
      stream: stream,
      builder: (context, snapshot) {
        Widget page = const SizedBox();
        // Return blank page if connection is not established
        if (snapshot.connectionState == ConnectionState.none) return page;
        UserStatus? userStatus = snapshot.data as UserStatus?;
        bool signedIn = userStatus?.signedIn ?? false;
        bool admin = userStatus?.admin ?? false;
        Map<String, Widget> routes = routeHelper.routes(
          signed: signedIn,
          isAdmin: admin,
        );
        if (routes.containsKey(uri.path)) {
          page = routes[uri.path]!;
          return page;
        }
        return routes[routeHelper.unknownRoute]!;
      },
    );
  }
}
