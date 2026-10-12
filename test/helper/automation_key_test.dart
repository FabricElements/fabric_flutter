import 'package:fabric_flutter/helper/automation_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a route named [routeName] whose body records the scoped key for [control].
Future<String> _keyOnRoute(
  WidgetTester tester, {
  required String routeName,
  required String control,
}) async {
  late String key;
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) {
          key = scopedAutomationKey(context, control);
          return const SizedBox();
        },
      ),
      initialRoute: routeName,
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

void main() {
  group('scopedAutomationKey', () {
    testWidgets('should prefix the control with the route path', (
      tester,
    ) async {
      // Arrange & Act
      final key = await _keyOnRoute(
        tester,
        routeName: '/dashboard',
        control: 'dateFilter',
      );

      // Assert
      expect(key, 'dashboard.dateFilter');
    });

    testWidgets('should ignore the query string when building the screen', (
      tester,
    ) async {
      // Arrange & Act
      final key = await _keyOnRoute(
        tester,
        routeName: '/dashboard?filters=abc',
        control: 'sort',
      );

      // Assert
      expect(key, 'dashboard.sort');
    });

    testWidgets('should join nested route segments with dots', (tester) async {
      // Arrange & Act
      final key = await _keyOnRoute(
        tester,
        routeName: '/account/dashboard',
        control: 'direction',
      );

      // Assert
      expect(key, 'account.dashboard.direction');
    });

    testWidgets('should keep the same control unique per route', (
      tester,
    ) async {
      // Arrange
      final userKey = await _keyOnRoute(
        tester,
        routeName: '/dashboard',
        control: 'dateFilter',
      );

      // Act
      final accountKey = await _keyOnRoute(
        tester,
        routeName: '/account/dashboard',
        control: 'dateFilter',
      );

      // Assert
      expect(accountKey, isNot(userKey));
    });

    testWidgets('should return the bare control when the route is unnamed', (
      tester,
    ) async {
      // Arrange
      late String key;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              key = scopedAutomationKey(context, 'dateFilter');
              return const SizedBox();
            },
          ),
        ),
      );

      // Assert
      expect(key, 'dateFilter');
    });
  });
}
