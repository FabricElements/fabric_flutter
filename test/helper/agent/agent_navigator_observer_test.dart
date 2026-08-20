import 'package:fabric_flutter/helper/agent/agent_navigator_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a route that renders [label] with the settings the observer reads.
MaterialPageRoute<void> _route(String label, {Object? arguments}) =>
    MaterialPageRoute<void>(
      settings: RouteSettings(name: label, arguments: arguments),
      builder: (context) => Text(label),
    );

void main() {
  group('AgentNavigatorObserver', () {
    late AgentNavigatorObserver observer;
    late GlobalKey<NavigatorState> navigatorKey;

    setUp(() {
      observer = AgentNavigatorObserver();
      navigatorKey = GlobalKey<NavigatorState>();
    });

    /// Pumps an app wired to [observer] with `/` as its initial route.
    Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        onGenerateRoute: (settings) =>
            _route(settings.name ?? '/', arguments: settings.arguments),
      ),
    );

    testWidgets('should report no route before any navigation', (
      WidgetTester tester,
    ) async {
      // Arrange
      // Act
      // Assert
      expect(observer.routeName, isNull);
      expect(observer.routeParams, isEmpty);
    });

    testWidgets('should record the initial route on push', (
      WidgetTester tester,
    ) async {
      // Arrange
      // Act
      await pumpApp(tester);

      // Assert
      expect(observer.routeName, '/');
    });

    testWidgets('should record a pushed route and its arguments', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpApp(tester);

      // Act
      navigatorKey.currentState!.pushNamed(
        '/orders',
        arguments: <String, dynamic>{'id': 7},
      );
      await tester.pumpAndSettle();

      // Assert
      expect(observer.routeName, '/orders');
      expect(observer.routeParams, <String, dynamic>{'id': 7});
    });

    testWidgets('should restore the previous route on pop', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpApp(tester);
      navigatorKey.currentState!.pushNamed('/orders');
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // Assert
      expect(observer.routeName, '/');
    });

    testWidgets('should record a replacement route', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpApp(tester);

      // Act
      navigatorKey.currentState!.pushReplacementNamed('/orders');
      await tester.pumpAndSettle();

      // Assert
      expect(observer.routeName, '/orders');
    });

    testWidgets('should restore the previous route on remove', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpApp(tester);
      navigatorKey.currentState!.pushNamed('/orders');
      await tester.pumpAndSettle();
      final removed = ModalRoute.of(tester.element(find.text('/orders')))!;

      // Act
      navigatorKey.currentState!.removeRoute(removed);
      await tester.pumpAndSettle();

      // Assert
      expect(observer.routeName, '/');
    });

    testWidgets('should ignore arguments that are not a map', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpApp(tester);

      // Act
      navigatorKey.currentState!.pushNamed('/orders', arguments: 'nope');
      await tester.pumpAndSettle();

      // Assert
      expect(observer.routeParams, isEmpty);
    });

    testWidgets('should clear the recorded route on reset', (
      WidgetTester tester,
    ) async {
      // Arrange
      await pumpApp(tester);

      // Act
      observer.reset();

      // Assert
      expect(observer.routeName, isNull);
    });
  });
}
