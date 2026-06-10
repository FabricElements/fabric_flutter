import 'package:flutter/material.dart';

/// Builds route tables that reflect the user's authentication state.
///
/// This helper wraps each configured route in a lightweight [Scaffold] and swaps
/// inaccessible destinations for either the authentication route or the unknown
/// route. That keeps access-control decisions centralized instead of scattering
/// them across page builders.
class RouteHelper {
  /// Creates a route policy from the supplied route groups and fallback routes.
  RouteHelper({
    required this.adminRoutes,
    required this.authenticatedRoutes,
    required this.authRoute,
    required this.publicRoutes,
    required this.routeMap,
    required this.unknownRoute,
    required this.initialRoute,
  });

  /// Lists routes that remain accessible even when the user is signed out.
  final List<String>? publicRoutes;

  /// Lists routes available to any authenticated user.
  final List<String>? authenticatedRoutes;

  /// Lists routes reserved for authenticated admin users.
  final List<String>? adminRoutes;

  /// Maps route names to the widgets that should be displayed for them.
  final Map<String, Widget> routeMap;

  /// Defines the fallback route used when signed-out users hit protected pages.
  final String? authRoute;

  /// Defines the fallback route used when signed-in users hit unknown pages.
  final String? unknownRoute;

  /// Identifies the route that should block back navigation with [PopScope].
  final String initialRoute;

  /// Returns the route table appropriate for the current auth and admin state.
  ///
  /// Signed-in users can reach [authenticatedRoutes] and, when [isAdmin] is
  /// `true`, [adminRoutes]. Signed-out users are limited to [publicRoutes] plus
  /// [authRoute]. Any inaccessible route is replaced with a safe fallback widget.
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
          endViewSigned0 = PopScope(child: value);
        } else {
          endViewSigned0 = value;
        }
      } else {
        endViewSigned0 = routeMap[endUnknownRoute];
      }
      endSignedIn.addAll({
        key: Scaffold(key: ValueKey(key), primary: false, body: endViewSigned0),
      });
    });

    /// Authenticated views
    routeMap.forEach((key, value) {
      Widget? endViewSigned;
      if (routesPublic.contains(key)) {
        if (key == initialRoute) {
          endViewSigned = PopScope(child: value);
        } else {
          endViewSigned = value;
        }
      } else {
        endViewSigned = routeMap[endAuthRoute];
      }
      endPublic.addAll({
        key: Scaffold(key: ValueKey(key), primary: false, body: endViewSigned),
      });
    });
    return signed ? endSignedIn : endPublic;
  }
}
