import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class RouteHelper {
  RouteHelper({
    required this.adminRoutes,
    required this.authenticatedRoutes,
    required this.authRoute,
    required this.isAdmin,
    required this.publicRoutes,
    required this.routeMap,
    required this.signedIn,
    required this.unknownRoute,
    required this.initialRoute,
  });

  final List<String>? publicRoutes;
  final List<String>? authenticatedRoutes;
  final List<String>? adminRoutes;
  final Map<String, Widget> routeMap;

  final bool signedIn;
  final bool isAdmin;
  final String? authRoute;
  final String? unknownRoute;
  final String initialRoute;

  Map<String, WidgetBuilder> routes() {
    print("routes called");
    Map<String, WidgetBuilder> _baseRoutes = {};
    String _authRoute = authRoute ?? "/auth";
    String _unknownRoute = unknownRoute ?? "/";

    List<String> _routes = [];
    if (!signedIn) {
      _routes.add(_authRoute);
    }
    if (publicRoutes != null) {
      _routes.addAll(publicRoutes!);
    }
    if (signedIn) {
      if (authenticatedRoutes != null) {
        _routes.addAll(authenticatedRoutes!);
      }
      if (isAdmin && adminRoutes != null) {
        _routes.addAll(adminRoutes!);
      }
    }

    routeMap.forEach((key, value) {
      Widget? _endView;
      if (_routes.contains(key)) {
        if (key == initialRoute) {
          _endView = WillPopScope(
            onWillPop: () async => true,
            child: value,
          );
        } else {
          _endView = value;
        }
      } else {
        if (!signedIn) {
          _endView = routeMap[_authRoute];
        } else {
          _endView = routeMap[_unknownRoute];
        }
      }
      if (_endView != null) {
        _baseRoutes.addAll({
          "$key": (context) => Scaffold(primary: false, body: _endView),
        });
      }
    });
    // _routes.forEach((key) {
    //   if (routeMap.containsKey(key)) {
    //     _baseRoutes.addAll({
    //       "$key": (context) => Scaffold(primary: false, body: routeMap[key]),
    //     });
    //   }
    // });
    String random = DateTime.now().millisecond.toString();
    _baseRoutes.addAll({
      "/random-$random": (context) => Scaffold(primary: false, body: routeMap[_unknownRoute]),
    });
    print(random);
    return _baseRoutes;
  }
}
