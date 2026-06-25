import 'package:fabric_flutter/component/screen_context.dart';
import 'package:fabric_flutter/component/smart_button.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmartButton', () {
    group('semantics', () {
      testWidgets('should fall back to button label when semanticsLabel is null', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Save Profile';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: label, path: '/save'),
              ),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == label);
        expect(node.properties.label, equals(label));
      });

      testWidgets('should use explicit semanticsLabel when provided', (
        WidgetTester tester,
      ) async {
        // Arrange
        const semanticsLabel = 'Custom Save Label';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: 'Save Profile', path: '/save'),
                semanticsLabel: semanticsLabel,
              ),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == semanticsLabel);
        expect(node.properties.label, equals(semanticsLabel));
      });

      testWidgets('should expose automationKey as semantics identifier', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Save Profile';
        const automationKey = 'profile_footer_button_save';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: label, path: '/save'),
                automationKey: automationKey,
              ),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == label);
        expect(node.properties.identifier, equals(automationKey));
      });

      testWidgets('should mark enabled when button has an actionable path', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Navigate';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: label, path: '/somewhere'),
              ),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == label);
        expect(node.properties.enabled, isTrue);
      });

      testWidgets('should mark disabled when button has no path or onTap', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Inactive Button';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: label),
              ),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == label);
        expect(node.properties.enabled, isFalse);
      });

      testWidgets('should mark enabled when button has an onTap callback', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Callback Button';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: label, onTap: () {}),
              ),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == label);
        expect(node.properties.enabled, isTrue);
      });
    });
  });

  group('ScreenContext', () {
    group('semantics', () {
      testWidgets('should inject route identifier from explicit routeName', (
        WidgetTester tester,
      ) async {
        // Arrange
        const routeName = '/dashboard';
        const expectedIdentifier = 'screen_/dashboard';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: ScreenContext(
              routeName: routeName,
              child: const SizedBox(),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.identifier == expectedIdentifier);
        expect(node.properties.identifier, equals(expectedIdentifier));
      });

      testWidgets('should have explicitChildNodes set to true', (
        WidgetTester tester,
      ) async {
        // Arrange
        const routeName = '/profile';

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: ScreenContext(
              routeName: routeName,
              child: const SizedBox(),
            ),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere(
              (s) => s.properties.identifier == 'screen_$routeName',
            );
        expect(node.explicitChildNodes, isTrue);
      });

      testWidgets('should leave identifier unset when routeName is null and no ambient route', (
        WidgetTester tester,
      ) async {
        // Act
        await tester.pumpWidget(
          // Wrap in a plain WidgetsApp without named routes so no ModalRoute exists.
          Directionality(
            textDirection: TextDirection.ltr,
            child: ScreenContext(child: const SizedBox()),
          ),
        );

        // Assert
        final Semantics node = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.container == true, orElse: () => const Semantics(child: SizedBox()));
        expect(node.properties.identifier, isNull);
      });
    });
  });
}
