import 'package:fabric_flutter/component/expressive_button_group.dart';
import 'package:fabric_flutter/helper/m3_tokens.dart';
import 'dart:ui' as ui;

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

/// Returns the corner radii that the segment labelled [label] currently uses.
BorderRadius _radiusOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final decoration = container.decoration! as ShapeDecoration;
  final shape = decoration.shape as RoundedRectangleBorder;
  return shape.borderRadius as BorderRadius;
}

const _items = [
  ExpressiveButtonItem(value: 'day', label: 'Day'),
  ExpressiveButtonItem(value: 'week', label: 'Week'),
  ExpressiveButtonItem(value: 'month', label: 'Month'),
];

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
        final handle = tester.ensureSemantics();
        // Arrange & Act
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
        final handle = tester.ensureSemantics();
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
        expect(find.bySemanticsLabel('Day'), findsOneWidget);
        expect(find.bySemanticsLabel('Week'), findsOneWidget);
        expect(find.bySemanticsLabel('Month'), findsOneWidget);
        handle.dispose();
      });
    });

    group('shape', () {
      testWidgets('should keep fully rounded outer ends on the edge segments', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          ExpressiveButtonGroup<String>(
            items: _items,
            selected: 'week',
            onChanged: (_) {},
          ),
        );

        // Assert
        expect(_radiusOf(tester, 'Day').topLeft.x, M3Shape.full);
        expect(_radiusOf(tester, 'Month').topRight.x, M3Shape.full);
      });

      testWidgets('should keep small inner corners on unselected segments', (
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
        expect(
          _radiusOf(tester, 'Week').topLeft.x,
          M3ExpressiveShape.segmentInner,
        );
        expect(
          _radiusOf(tester, 'Week').topRight.x,
          M3ExpressiveShape.segmentInner,
        );
      });

      testWidgets('should morph the selected segment to the selected radius', (
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
        expect(
          _radiusOf(tester, 'Week').topLeft.x,
          M3ExpressiveShape.segmentSelected,
        );
      });
    });
  });
}
