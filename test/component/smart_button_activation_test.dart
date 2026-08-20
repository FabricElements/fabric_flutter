import 'package:fabric_flutter/component/smart_button.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [button] as the home route of an app that also exposes `/next`.
///
/// Routing is wired so a test can assert both halves of activation: the
/// callback and the navigation that may follow it.
Future<void> _pump(WidgetTester tester, ButtonOptions button) async {
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => Scaffold(body: SmartButton(button: button)),
        '/next': (context) => const Scaffold(body: Text('next page')),
      },
    ),
  );
}

void main() {
  group('SmartButton', () {
    group('activation', () {
      testWidgets('should invoke onTap when the button has no path', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await _pump(
          tester,
          ButtonOptions(label: 'Remove', onTap: () => taps++),
        );

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(taps, 1);
      });

      testWidgets('should invoke onTap once per tap', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await _pump(
          tester,
          ButtonOptions(label: 'Remove', onTap: () => taps++),
        );

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(taps, 2);
      });

      testWidgets('should not navigate when the button has no path', (
        WidgetTester tester,
      ) async {
        // Arrange
        await _pump(tester, ButtonOptions(label: 'Remove', onTap: () {}));

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('next page'), findsNothing);
      });

      testWidgets('should still invoke onTap and navigate when a path is set', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await _pump(
          tester,
          ButtonOptions(label: 'Open', path: '/next', onTap: () => taps++),
        );

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(taps, 1);
        expect(find.text('next page'), findsOneWidget);
      });

      testWidgets('should navigate when a path is set without an onTap', (
        WidgetTester tester,
      ) async {
        // Arrange
        await _pump(tester, ButtonOptions(label: 'Open', path: '/next'));

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('next page'), findsOneWidget);
      });

      testWidgets(
        'should do nothing when the button has no path and no onTap',
        (WidgetTester tester) async {
          // Arrange
          await _pump(tester, ButtonOptions(label: 'Inert'));

          // Act
          await tester.tap(find.byType(SmartButton), warnIfMissed: false);
          await tester.pumpAndSettle();

          // Assert
          expect(find.text('next page'), findsNothing);
          expect(find.text('Inert'), findsOneWidget);
        },
      );

      testWidgets('should replace the current route when pop is true', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => const Scaffold(body: Text('home')),
              '/detail': (context) => Scaffold(
                body: SmartButton(
                  pop: true,
                  button: ButtonOptions(
                    label: 'Open',
                    path: '/next',
                    onTap: () => taps++,
                  ),
                ),
              ),
              '/next': (context) => const Scaffold(body: Text('next page')),
            },
          ),
        );
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pushNamed('/detail');
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byType(SmartButton));
        await tester.pumpAndSettle();

        // Assert
        expect(taps, 1);
        expect(find.text('next page'), findsOneWidget);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      });
    });
  });
}
