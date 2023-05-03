import 'package:flutter/material.dart';

/// RouteHelper Enables/Disables routes depending on credentials
class RouteHelper {
  RouteHelper({
    required this.adminRoutes,
    required this.authenticatedRoutes,
    required this.authRoute,
    required this.publicRoutes,
    required this.routeMap,
    required this.unknownRoute,
    required this.initialRoute,
  });

  final List<String>? publicRoutes;
  final List<String>? authenticatedRoutes;
  final List<String>? adminRoutes;
  final Map<String, Widget> routeMap;

  final String? authRoute;
  final String? unknownRoute;
  final String initialRoute;

  Map<String, Widget> routes({bool signed = false, bool isAdmin = false}) {
    Map<String, Widget> endSignedIn = {};
    Map<String, Widget> endPublic = {};
    String endAuthRoute = authRoute ?? '/auth';
    String endUnknownRoute = unknownRoute ?? '/';

    List<String> routesSignedIn = [];
    List<String> routesPublic = [];
    if (!signed) {
      routesPublic.add(endAuthRoute);
    }
    if (publicRoutes != null) {
      routesSignedIn.addAll(publicRoutes!);
      routesPublic.addAll(publicRoutes!);
    }
    if (signed) {
      if (authenticatedRoutes != null) {
        routesSignedIn.addAll(authenticatedRoutes!);
      }
      if (isAdmin && adminRoutes != null) {
        routesSignedIn.addAll(adminRoutes!);
      }
    }

    /// Authenticated views
    routeMap.forEach((key, value) {
      Widget? endViewSigned0;
      if (routesSignedIn.contains(key)) {
        if (key == initialRoute) {
          endViewSigned0 = WillPopScope(
            onWillPop: () async => true,
            child: value,
          );
        } else {
          endViewSigned0 = value;
        }
      } else {
        endViewSigned0 = routeMap[endUnknownRoute];
      }
      endSignedIn.addAll({
        key: Scaffold(primary: false, body: endViewSigned0),
      });
    });

    /// Authenticated views
    routeMap.forEach((key, value) {
      Widget? endViewSigned;
      if (routesPublic.contains(key)) {
        if (key == initialRoute) {
          endViewSigned = WillPopScope(
            onWillPop: () async => true,
            child: value,
          );
        } else {
          endViewSigned = value;
        }
      } else {
        endViewSigned = routeMap[endAuthRoute];
      }
      endPublic.addAll({
        key: Scaffold(primary: false, body: endViewSigned),
      });
    });
    return signed ? endSignedIn : endPublic;
  }
}
