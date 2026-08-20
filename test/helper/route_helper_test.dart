import 'package:fabric_flutter/helper/route_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [RouteHelper] with a shared, predictable route map.
RouteHelper buildHelper({
  List<String>? publicRoutes = const ['/'],
  List<String>? authenticatedRoutes = const ['/home'],
  List<String>? adminRoutes = const ['/admin'],
  String? authRoute = '/auth',
  String? unknownRoute = '/',
  String initialRoute = '/',
}) => RouteHelper(
  adminRoutes: adminRoutes,
  authenticatedRoutes: authenticatedRoutes,
  authRoute: authRoute,
  publicRoutes: publicRoutes,
  routeMap: {
    '/': const Text('public'),
    '/auth': const Text('auth'),
    '/home': const Text('home'),
    '/admin': const Text('admin'),
  },
  unknownRoute: unknownRoute,
  initialRoute: initialRoute,
);

/// Returns the text rendered by the innermost body widget for [route].
///
/// Returns `null` when the route resolves to no widget at all, which happens
/// when the configured fallback route is missing from the route map.
String? bodyOf(Map<String, Widget> routes, String route) {
  final scaffold = routes[route] as Scaffold?;
  var body = scaffold?.body;
  if (body is PopScope) body = body.child;
  return (body as Text?)?.data;
}

void main() {
  group('RouteHelper.routes', () {
    test('should wrap every route in a Scaffold keyed by its name', () {
      // Arrange
      final helper = buildHelper();

      // Act
      final routes = helper.routes(signed: true);

      // Assert
      expect(routes.keys, containsAll(['/', '/auth', '/home', '/admin']));
      for (final entry in routes.entries) {
        expect(entry.value, isA<Scaffold>());
        expect((entry.value as Scaffold).key, ValueKey(entry.key));
        expect((entry.value as Scaffold).primary, isFalse);
      }
    });

    test('should wrap the initial route in a PopScope', () {
      // Arrange
      final helper = buildHelper(initialRoute: '/');

      // Act
      final routes = helper.routes(signed: true);

      // Assert
      expect((routes['/'] as Scaffold).body, isA<PopScope>());
      expect((routes['/home'] as Scaffold).body, isNot(isA<PopScope>()));
    });

    group('signed out', () {
      test('should expose public routes and the auth route', () {
        // Arrange
        final helper = buildHelper();

        // Act
        final routes = helper.routes(signed: false);

        // Assert
        expect(bodyOf(routes, '/'), 'public');
        expect(bodyOf(routes, '/auth'), 'auth');
      });

      test('should replace authenticated routes with the auth route', () {
        // Arrange
        final helper = buildHelper();

        // Act
        final routes = helper.routes(signed: false);

        // Assert
        expect(bodyOf(routes, '/home'), 'auth');
        expect(bodyOf(routes, '/admin'), 'auth');
      });

      test('should default the auth route to /auth when none is given', () {
        // Arrange
        final helper = buildHelper(authRoute: null);

        // Act
        final routes = helper.routes(signed: false);

        // Assert
        expect(bodyOf(routes, '/home'), 'auth');
      });
    });

    group('signed in', () {
      test('should expose public and authenticated routes', () {
        // Arrange
        final helper = buildHelper();

        // Act
        final routes = helper.routes(signed: true);

        // Assert
        expect(bodyOf(routes, '/'), 'public');
        expect(bodyOf(routes, '/home'), 'home');
      });

      test('should replace admin routes for non-admin users', () {
        // Arrange
        final helper = buildHelper();

        // Act
        final routes = helper.routes(signed: true);

        // Assert: falls back to the unknown route widget.
        expect(bodyOf(routes, '/admin'), 'public');
      });

      test('should expose admin routes for admin users', () {
        // Arrange
        final helper = buildHelper();

        // Act
        final routes = helper.routes(signed: true, isAdmin: true);

        // Assert
        expect(bodyOf(routes, '/admin'), 'admin');
      });

      test('should replace the auth route with the unknown route', () {
        // Arrange
        final helper = buildHelper();

        // Act
        final routes = helper.routes(signed: true);

        // Assert: /auth is not reachable once signed in.
        expect(bodyOf(routes, '/auth'), 'public');
      });
    });

    group('null route groups', () {
      test('should tolerate null public routes when signed out', () {
        // Arrange
        final helper = buildHelper(publicRoutes: null);

        // Act
        final routes = helper.routes(signed: false);

        // Assert
        expect(bodyOf(routes, '/auth'), 'auth');
        expect(bodyOf(routes, '/'), 'auth');
      });

      test('should tolerate null authenticated and admin routes', () {
        // Arrange
        final helper = buildHelper(
          authenticatedRoutes: null,
          adminRoutes: null,
        );

        // Act
        final routes = helper.routes(signed: true, isAdmin: true);

        // Assert
        expect(bodyOf(routes, '/home'), 'public');
        expect(bodyOf(routes, '/admin'), 'public');
      });

      test('should yield a null body when the unknown route is unmapped', () {
        // Arrange
        final helper = buildHelper(unknownRoute: '/missing');

        // Act
        final routes = helper.routes(signed: true);

        // Assert
        expect(bodyOf(routes, '/admin'), isNull);
      });
    });
  });
}
