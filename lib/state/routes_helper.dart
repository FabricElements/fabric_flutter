import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateRoutes extends ChangeNotifier {
  StateRoutes();

  List<String>? _publicRoutes;
  List<String>? _authenticatedRoutes;
  List<String>? _adminRoutes;
  Map<String, Widget> _routeMap = {};
  String _authRoute = "/auth";
  String _unknownRoute = "/";
  String _initialRoute = "/";
  bool _signedIn = false;
  bool _admin = false;

  /// Routes that don't require any authentication
  set publicRoutes(List<String>? routes) {
    _publicRoutes = routes ?? null;
  }

  /// Routes available only for authenticated users
  set authenticatedRoutes(List<String>? routes) {
    _authenticatedRoutes = routes ?? null;
  }

  /// Routes available only for admins
  set adminRoutes(List<String>? routes) {
    _adminRoutes = routes ?? null;
  }

  /// Routes available only for admins
  set routeMap(Map<String, Widget>? routes) {
    _routeMap = routes ?? {};
  }

  set authRoute(String path) => _authRoute = path;

  set unknownRoute(String path) => _unknownRoute = path;

  set initialRoute(String path) => _initialRoute = path;

  /// Set StateUser object
  set admin(bool value) {
    _admin = value;
    notifyListeners();
  }

  set signedIn(bool value) {
    _signedIn = value;
    notifyListeners();
  }

  /// Get the final routes
  Map<String, WidgetBuilder> get routes {
    print(":::::: updated routes ::::::::");
    Map<String, WidgetBuilder> _baseRoutes = {};

    List<String> _routes = [];
    if (_signedIn) {
      _routes.add(_authRoute);
    }
    if (_publicRoutes != null) {
      _routes.addAll(_publicRoutes!);
    }
    if (_signedIn) {
      if (_authenticatedRoutes != null) {
        _routes.addAll(_authenticatedRoutes!);
      }
      if (_admin && _adminRoutes != null) {
        _routes.addAll(_adminRoutes!);
      }
    }

    _routeMap.forEach((key, value) {
      Widget? _endView;
      if (_routes.contains(key)) {
        if (key == _initialRoute) {
          _endView = WillPopScope(
            onWillPop: () async => true,
            child: value,
          );
        } else {
          _endView = value;
        }
      } else {
        if (_signedIn) {
          _endView = _routeMap[_authRoute];
        } else {
          _endView = _routeMap[_unknownRoute];
        }
      }
      if (_endView != null) {
        _baseRoutes.addAll({
          "$key": (context) => Scaffold(primary: false, body: _endView),
        });
      }
    });
    String random = DateTime.now().millisecond.toString();
    _baseRoutes.addAll({
      "/random-$random": (context) =>
          Scaffold(primary: false, body: _routeMap[_unknownRoute]),
    });
    print(random);
    return _baseRoutes;
  }
}
