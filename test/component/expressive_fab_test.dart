import 'dart:ui' as ui;

import 'package:fabric_flutter/component/expressive_fab.dart';
import 'package:fabric_flutter/helper/m3_expressive_shape_border.dart';
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

/// Returns the outline the FAB's surface currently uses.
ExpressiveShapeBorder _currentShape(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(ExpressiveFab),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.shape! as ExpressiveShapeBorder;
}

/// Asserts [shape] is within a small tolerance of [target].
///
/// Springs settle near their target rather than exactly on it, so the shape is
/// compared by its fields with a tolerance instead of by equality.
void _expectShape(ExpressiveShapeBorder shape, ExpressiveShapeBorder target) {
  expect(shape.amplitude, closeTo(target.amplitude, 0.002));
  expect(shape.exponent, closeTo(target.exponent, 0.02));
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
          ),
        );

        // Assert
        expect(tester.getSize(find.byType(SizedBox).first).width, 56);
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
        expect(tester.getSize(find.byType(SizedBox).first).width, 80);
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
          ),
        );

        // Assert
        expect(tester.getSize(find.byType(SizedBox).first).width, 96);
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

      testWidgets('should expose the semantics label to assistive tech', (
        WidgetTester tester,
      ) async {
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
      });

      testWidgets('should mark the button disabled when onPressed is null', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await _pump(
          tester,
          const ExpressiveFab(icon: Icons.add, semanticsLabel: 'Add'),
        );

        // Assert
        final semantics = tester.getSemantics(find.bySemanticsLabel('Add'));
        expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
        handle.dispose();
      });
    });

    group('press morph', () {
      testWidgets('should rest as a squircle with no lobes', (
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
        _expectShape(_currentShape(tester), ExpressiveShapeBorder.squircle);
      });

      testWidgets('should settle into the cookie while held', (
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
        _expectShape(_currentShape(tester), ExpressiveShapeBorder.cookie);

        // Cleanup
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('should pass through intermediate shapes while springing', (
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));

        // Assert: the morph is a spring, so an early frame is between the two.
        final amplitude = _currentShape(tester).amplitude;
        expect(amplitude, greaterThan(0));
        expect(amplitude, lessThan(ExpressiveShapeBorder.cookie.amplitude));

        // Cleanup
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('should spring back to the squircle after release', (
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
        _expectShape(_currentShape(tester), ExpressiveShapeBorder.squircle);
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
        _expectShape(_currentShape(tester), ExpressiveShapeBorder.squircle);

        // Cleanup
        await gesture.up();
        await tester.pumpAndSettle();
      });
    });
  });
}
