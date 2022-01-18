import 'package:flutter/material.dart';

/// [RouteHelper] Enables/Disables routes depending on credentials
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
    required this.context,
  });

  final List<String>? publicRoutes;
  final List<String>? authenticatedRoutes;
  final List<String>? adminRoutes;
  final Map<String, Widget> routeMap;
  final BuildContext context;

  final bool signedIn;
  final bool isAdmin;
  final String? authRoute;
  final String? unknownRoute;
  final String initialRoute;

  Map<String, Widget> routes(bool signed) {
    Map<String, Widget> _endSignedIn = {};
    Map<String, Widget> _endPublic = {};
    String _authRoute = authRoute ?? '/auth';
    String _unknownRoute = unknownRoute ?? '/';

    List<String> _routesSignedIn = [];
    List<String> _routesPublic = [];
    if (!signedIn) {
      _routesPublic.add(_authRoute);
    }
    if (publicRoutes != null) {
      _routesSignedIn.addAll(publicRoutes!);
      _routesPublic.addAll(publicRoutes!);
    }
    if (signedIn) {
      if (authenticatedRoutes != null) {
        _routesSignedIn.addAll(authenticatedRoutes!);
      }
      if (isAdmin && adminRoutes != null) {
        _routesSignedIn.addAll(adminRoutes!);
      }
    }

    /// Authenticated views
    routeMap.forEach((key, value) {
      Widget? _endViewSigned;
      if (_routesSignedIn.contains(key)) {
        if (key == initialRoute) {
          _endViewSigned = WillPopScope(
            onWillPop: () async => true,
            child: value,
          );
        } else {
          _endViewSigned = value;
        }
      } else {
        _endViewSigned = routeMap[_unknownRoute];
      }
      _endSignedIn.addAll({
        "$key": Scaffold(primary: false, body: _endViewSigned),
      });
    });

    /// Authenticated views
    routeMap.forEach((key, value) {
      Widget? _endViewSigned;
      if (_routesPublic.contains(key)) {
        if (key == initialRoute) {
          _endViewSigned = WillPopScope(
            onWillPop: () async => true,
            child: value,
          );
        } else {
          _endViewSigned = value;
        }
      } else {
        _endViewSigned = routeMap[_authRoute];
      }
      _endPublic.addAll({
        '$key': Scaffold(primary: false, body: _endViewSigned),
      });
    });
    return signed ? _endSignedIn : _endPublic;
  }

  Map<String, Widget> get routesSignedIn => routes(true);

  Map<String, Widget> get routesPublic => routes(false);

  Map<String, Widget> endRoutes({
    required bool signedIn,
  }) {
    return routesSignedIn;
  }
}
