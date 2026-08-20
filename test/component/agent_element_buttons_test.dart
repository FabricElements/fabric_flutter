import 'package:fabric_flutter/component/card_button.dart';
import 'package:fabric_flutter/component/smart_button.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal app scaffolding required to pump a component.
Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 320, height: 320, child: child)),
);

void main() {
  group('Agent element wiring', () {
    final index = AgentElementIndex.instance;

    setUp(index.reset);
    tearDown(index.reset);

    group('SmartButton', () {
      testWidgets('should index itself when an automationKey is given', (
        WidgetTester tester,
      ) async {
        // Arrange
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: 'Save Profile', path: '/save'),
                automationKey: 'home_toolbar_button_save',
                semanticHint: 'Saves the profile',
              ),
            ),
          ),
        );

        // Assert
        final snapshot = index.snapshotOf('home_toolbar_button_save');
        expect(snapshot, isNotNull);
        expect(snapshot!.type, AgentElementType.button);
        expect(snapshot.label, 'Save Profile');
        expect(snapshot.hint, 'Saves the profile');
        expect(snapshot.enabled, isTrue);
      });

      testWidgets('should index nothing when automationKey is null', (
        WidgetTester tester,
      ) async {
        // Arrange
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: 'Save Profile', path: '/save'),
              ),
            ),
          ),
        );

        // Assert
        expect(index.ids, isEmpty);
      });

      testWidgets('should expose an activator that runs the button action', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(
                  label: 'Save Profile',
                  onTap: () => taps++,
                ),
                automationKey: 'home_toolbar_button_save',
              ),
            ),
          ),
        );

        // Act
        await index.handle('home_toolbar_button_save')!.activator!();
        await tester.pumpAndSettle();

        // Assert
        expect(taps, 1);
      });

      testWidgets('should report a disabled button as not enabled', (
        WidgetTester tester,
      ) async {
        // Arrange
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: 'Save Profile'),
                automationKey: 'home_toolbar_button_save',
              ),
            ),
          ),
        );

        // Assert
        final handle = index.handle('home_toolbar_button_save')!;
        expect(handle.enabled, isFalse);
        expect(handle.canActivate, isFalse);
      });

      testWidgets('should remove itself from the index on dispose', (
        WidgetTester tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartButton(
                button: ButtonOptions(label: 'Save Profile', path: '/save'),
                automationKey: 'home_toolbar_button_save',
              ),
            ),
          ),
        );

        // Act
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));

        // Assert
        expect(index.ids, isEmpty);
      });
    });

    group('CardButton', () {
      testWidgets('should index itself and expose its activator', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Open orders',
              onPressed: () => taps++,
              automationKey: 'home_grid_button_orders',
              semanticHint: 'Opens the orders list',
            ),
          ),
        );
        await index.handle('home_grid_button_orders')!.activator!();

        // Assert
        final snapshot = index.snapshotOf('home_grid_button_orders')!;
        expect(snapshot.type, AgentElementType.button);
        expect(snapshot.label, 'Open orders');
        expect(snapshot.hint, 'Opens the orders list');
        expect(taps, 1);
      });

      testWidgets('should index nothing when automationKey is null', (
        WidgetTester tester,
      ) async {
        // Arrange
        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Open orders',
              onPressed: () {},
            ),
          ),
        );

        // Assert
        expect(index.ids, isEmpty);
      });
    });
  });
}
