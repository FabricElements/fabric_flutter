import 'package:fabric_flutter/component/expressive_fab.dart';
import 'package:fabric_flutter/helper/m3_tokens.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a themed scaffold so theme lookups resolve.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Returns the corner radius that the FAB's animated decoration currently uses.
double _currentRadius(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.byType(AnimatedContainer),
  );
  final decoration = container.decoration! as ShapeDecoration;
  final shape = decoration.shape as RoundedRectangleBorder;
  return (shape.borderRadius as BorderRadius).topLeft.x;
}

void main() {
  group('ExpressiveFab', () {
    group('sizes', () {
      testWidgets('should use the 56dp container for the small size', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          const ExpressiveFab(
            icon: Icons.add,
            semanticsLabel: 'Add',
            size: ExpressiveFabSize.small,
            onPressed: null,
          ),
        );

        // Assert
        expect(tester.getSize(find.byType(ExpressiveFab)).width, 56);
      });

      testWidgets('should use the 80dp container by default', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          const ExpressiveFab(icon: Icons.add, semanticsLabel: 'Add'),
        );

        // Assert
        expect(tester.getSize(find.byType(ExpressiveFab)).width, 80);
      });

      testWidgets('should use the 96dp container for the large size', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          const ExpressiveFab(
            icon: Icons.add,
            semanticsLabel: 'Add',
            size: ExpressiveFabSize.large,
            onPressed: null,
          ),
        );

        // Assert
        expect(tester.getSize(find.byType(ExpressiveFab)).width, 96);
      });
    });

    group('interaction', () {
      testWidgets('should run onPressed when tapped', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;
        await _pump(
          tester,
          ExpressiveFab(
            icon: Icons.add,
            semanticsLabel: 'Add',
            onPressed: () => taps++,
          ),
        );

        // Act
        await tester.tap(find.byType(InkWell));
        await tester.pump();

        // Assert
        expect(taps, 1);
      });

      testWidgets('should mark the button disabled when onPressed is null', (
        WidgetTester tester,
      ) async {
        final handle = tester.ensureSemantics();
        // Arrange & Act
        await _pump(
          tester,
          const ExpressiveFab(icon: Icons.add, semanticsLabel: 'Add'),
        );

        // Assert
        final semantics = tester.getSemantics(find.bySemanticsLabel('Add'));
        expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
        handle.dispose();
      });

      testWidgets('should expose the semantics label to assistive tech', (
        WidgetTester tester,
      ) async {
        final handle = tester.ensureSemantics();
        // Arrange & Act
        await _pump(
          tester,
          ExpressiveFab(
            icon: Icons.add,
            semanticsLabel: 'Create',
            onPressed: () {},
          ),
        );

        // Assert
        expect(find.bySemanticsLabel('Create'), findsOneWidget);
        handle.dispose();
      });
    });

    group('press morph', () {
      testWidgets('should rest at the size radius before any press', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          ExpressiveFab(
            icon: Icons.add,
            semanticsLabel: 'Add',
            onPressed: () {},
          ),
        );

        // Assert
        expect(_currentRadius(tester), M3ExpressiveShape.fabLarge);
      });

      testWidgets('should morph to a full circle while held', (
        WidgetTester tester,
      ) async {
        // Arrange
        await _pump(
          tester,
          ExpressiveFab(
            icon: Icons.add,
            semanticsLabel: 'Add',
            onPressed: () {},
          ),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InkWell)),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(_currentRadius(tester), M3ExpressiveShape.fabPressed);

        // Cleanup
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('should return to the resting radius after release', (
        WidgetTester tester,
      ) async {
        // Arrange
        await _pump(
          tester,
          ExpressiveFab(
            icon: Icons.add,
            semanticsLabel: 'Add',
            onPressed: () {},
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InkWell)),
        );
        await tester.pumpAndSettle();

        // Act
        await gesture.up();
        await tester.pumpAndSettle();

        // Assert
        expect(_currentRadius(tester), M3ExpressiveShape.fabLarge);
      });

      testWidgets('should not morph when disabled', (
        WidgetTester tester,
      ) async {
        // Arrange
        await _pump(
          tester,
          const ExpressiveFab(icon: Icons.add, semanticsLabel: 'Add'),
        );

        // Act
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InkWell)),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(_currentRadius(tester), M3ExpressiveShape.fabLarge);

        // Cleanup
        await gesture.up();
        await tester.pumpAndSettle();
      });
    });
  });
}
