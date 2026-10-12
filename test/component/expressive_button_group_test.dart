import 'dart:ui' as ui;

import 'package:fabric_flutter/component/expressive_button_group.dart';
import 'package:fabric_flutter/helper/m3_expressive_shape_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [group] inside a themed scaffold so theme lookups resolve.
Future<void> _pump(WidgetTester tester, Widget group) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: group),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Returns the outline of the segment labelled [label].
ExpressiveShapeBorder _shapeOf(WidgetTester tester, String label) {
  final material = tester.widget<Material>(
    find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
  );
  return material.shape! as ExpressiveShapeBorder;
}

const _items = [
  ExpressiveButtonItem(value: 'day', label: 'Day'),
  ExpressiveButtonItem(value: 'week', label: 'Week'),
  ExpressiveButtonItem(value: 'month', label: 'Month'),
];

/// Asserts [shape] is within a small tolerance of [target].
///
/// Springs settle near their target rather than exactly on it, so the shape is
/// compared by its fields with a tolerance instead of by equality.
void _expectShape(ExpressiveShapeBorder shape, ExpressiveShapeBorder target) {
  expect(shape.amplitude, closeTo(target.amplitude, 0.002));
  expect(shape.exponent, closeTo(target.exponent, 0.02));
}

void main() {
  group('ExpressiveButtonGroup', () {
    group('interaction', () {
      testWidgets('should report the tapped segment value', (
        WidgetTester tester,
      ) async {
        // Arrange
        String? tapped;
        await _pump(
          tester,
          ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'day',
            onChanged: (value) => tapped = value,
          ),
        );

        // Act
        await tester.tap(find.text('Week'));
        await tester.pump();

        // Assert
        expect(tapped, 'week');
      });

      testWidgets('should mark every segment disabled when the group is', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await _pump(
          tester,
          const ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'day',
            onChanged: null,
          ),
        );

        // Assert
        final semantics = tester.getSemantics(find.bySemanticsLabel('Week'));
        expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
        handle.dispose();
      });

      testWidgets('should expose each segment as a labelled button', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await _pump(
          tester,
          ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'day',
            onChanged: (_) {},
          ),
        );

        // Assert
        expect(find.bySemanticsLabel('Day'), findsOneWidget);
        expect(find.bySemanticsLabel('Week'), findsOneWidget);
        expect(find.bySemanticsLabel('Month'), findsOneWidget);
        handle.dispose();
      });
    });

    group('shape', () {
      testWidgets('should rest unselected segments as squircles', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'day',
            onChanged: (_) {},
          ),
        );

        // Assert
        _expectShape(_shapeOf(tester, 'Week'), ExpressiveShapeBorder.squircle);
      });

      testWidgets('should spring the selected segment into the cookie', (
        WidgetTester tester,
      ) async {
        // Arrange
        await _pump(
          tester,
          ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'day',
            onChanged: (_) {},
          ),
        );

        // Act
        await _pump(
          tester,
          ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'week',
            onChanged: (_) {},
          ),
        );

        // Assert
        _expectShape(_shapeOf(tester, 'Week'), ExpressiveShapeBorder.cookie);
        _expectShape(_shapeOf(tester, 'Day'), ExpressiveShapeBorder.squircle);
      });

      testWidgets('should pass through intermediate shapes while springing', (
        WidgetTester tester,
      ) async {
        // Arrange
        await _pump(
          tester,
          ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'day',
            onChanged: (_) {},
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ExpressiveButtonGroup<String>(
                  items: _items,
                  selected: 'week',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        // Act
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));

        // Assert
        final amplitude = _shapeOf(tester, 'Week').amplitude;
        expect(amplitude, greaterThan(0));
        expect(amplitude, lessThan(ExpressiveShapeBorder.cookie.amplitude));
      });
    });
  });
}
