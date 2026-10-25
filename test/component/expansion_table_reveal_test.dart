import 'package:fabric_flutter/component/expansion_table.dart';
import 'package:fabric_flutter/helper/scroll_reveal.dart';
import 'package:fabric_flutter/serialized/table_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [future] to completion by pumping real frames in [step] increments.
///
/// [ScrollReveal.reveal] advances one frame at a time from a post-frame
/// callback, so a plain [WidgetTester.pumpAndSettle] cannot drive it — each
/// pump only produces the single frame the loop is currently waiting for.
/// Returns the resolved value, or `null` when the loop never completed.
Future<bool?> _driveFrames(
  WidgetTester tester,
  Future<bool> future, {
  Duration step = const Duration(milliseconds: 50),
  int maxFrames = 400,
}) async {
  bool? result;
  var completed = false;
  future.then(
    (value) {
      result = value;
      completed = true;
    },
    onError: (_) {
      completed = true;
    },
  );
  for (var i = 0; i < maxFrames && !completed; i++) {
    await tester.pump(step);
  }
  return result;
}

/// Builds a table fixture with [count] rows over [columns] string columns.
TableData _table({int count = 30, int columns = 3, String prefix = 'Row'}) =>
    TableData(
      header: [
        for (var index = 0; index < columns; index++)
          TableColumnData(value: 'Col ${index + 1}'),
      ],
      rows: [
        for (var index = 0; index < count; index++)
          TableRowData(
            cells: [for (var c = 0; c < columns; c++) '$prefix $index c$c'],
          ),
      ],
    );

/// Builds a two-row table whose second row owns an expandable child.
TableData _nestable() => TableData(
  header: [TableColumnData(value: 'Col 1')],
  rows: [
    TableRowData(cells: ['Root row']),
    TableRowData(
      cells: ['Parent row'],
      child: TableData(
        header: [TableColumnData(value: 'Col 1')],
        rows: [
          TableRowData(cells: ['Kid row']),
        ],
      ),
    ),
  ],
);

/// Wraps [child] in a sized vertical scroller so reveal targets can sit far
/// outside the viewport.
Widget _scroller(Widget child, {double height = 300}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: height,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  group('ExpansionTable reveal', () {
    testWidgets('should scroll a distant root row into view', (tester) async {
      // Arrange
      final controller = RevealController();
      final data = _table(count: 40);
      await tester.pumpWidget(
        _scroller(
          ExpansionTable(data: data, controller: controller, columnWidth: 300),
        ),
      );
      await tester.pumpAndSettle();
      final target = data.rows[25];

      // Act
      final revealed = await _driveFrames(tester, controller.reveal(target));

      // Assert
      expect(revealed, isTrue);
      final rect = tester.getRect(find.text('Row 25 c0'));
      expect(rect.top, greaterThanOrEqualTo(-1));
      expect(rect.bottom, lessThanOrEqualTo(301));
    });

    testWidgets('should expand inactive ancestors before revealing a child', (
      tester,
    ) async {
      // Arrange
      final controller = RevealController();
      final data = _nestable();
      final childRow = data.rows[1].child!.rows.first;
      await tester.pumpWidget(
        _scroller(
          ExpansionTable(data: data, controller: controller, columnWidth: 300),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kid row'), findsNothing);

      // Act
      final revealed = await _driveFrames(tester, controller.reveal(childRow));

      // Assert
      expect(revealed, isTrue);
      expect(data.rows[1].active, isTrue);
      expect(find.text('Kid row'), findsOneWidget);
    });

    testWidgets('should return false when the row is not part of the data', (
      tester,
    ) async {
      // Arrange
      final controller = RevealController();
      await tester.pumpWidget(
        _scroller(ExpansionTable(data: _table(), controller: controller)),
      );
      await tester.pumpAndSettle();

      // Act
      final revealed = await controller.reveal(TableRowData(cells: ['x']));

      // Assert
      expect(revealed, isFalse);
    });

    testWidgets('should reveal the root row at an index', (tester) async {
      // Arrange
      final controller = RevealController();
      await tester.pumpWidget(
        _scroller(
          ExpansionTable(data: _table(count: 40), controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      final revealed = await _driveFrames(tester, controller.reveal(30));

      // Assert
      expect(revealed, isTrue);
      expect(find.text('Row 30 c0'), findsOneWidget);
    });

    testWidgets('should return false for an out-of-range row index', (
      tester,
    ) async {
      // Arrange
      final controller = RevealController();
      await tester.pumpWidget(
        _scroller(ExpansionTable(data: _table(), controller: controller)),
      );
      await tester.pumpAndSettle();

      // Act
      final negative = await controller.reveal(-1);
      final beyond = await controller.reveal(999);

      // Assert
      expect(negative, isFalse);
      expect(beyond, isFalse);
    });

    testWidgets('should scroll the horizontal axis to a later column', (
      tester,
    ) async {
      // Arrange
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = RevealController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpansionTable(
              data: _table(count: 3),
              controller: controller,
              columnWidth: 300,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Col 3')).left, greaterThan(360));

      // Act
      final revealed = await _driveFrames(
        tester,
        controller.reveal(RevealTarget(column: 2)),
      );

      // Assert
      expect(revealed, isTrue);
      expect(tester.getRect(find.text('Col 3')).left, lessThan(360));
    });

    testWidgets('should keep an already visible column in place', (
      tester,
    ) async {
      // Arrange
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = RevealController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpansionTable(
              data: _table(count: 3),
              controller: controller,
              columnWidth: 300,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.text('Col 1'));

      // Act
      final revealed = await _driveFrames(
        tester,
        controller.reveal(RevealTarget(column: 0)),
      );

      // Assert
      expect(revealed, isTrue);
      expect(tester.getRect(find.text('Col 1')), before);
    });

    testWidgets('should return false for an out-of-range column index', (
      tester,
    ) async {
      // Arrange
      final controller = RevealController();
      await tester.pumpWidget(
        _scroller(ExpansionTable(data: _table(), controller: controller)),
      );
      await tester.pumpAndSettle();

      // Act
      final negative = await controller.reveal(RevealTarget(column: -1));
      final beyond = await controller.reveal(RevealTarget(column: 99));

      // Assert
      expect(negative, isFalse);
      expect(beyond, isFalse);
    });

    testWidgets('should return false while no table is attached', (
      tester,
    ) async {
      // Arrange
      final controller = RevealController();

      // Act
      final byRow = await controller.reveal(TableRowData(cells: ['x']));
      final byIndex = await controller.reveal(0);
      final byColumn = await controller.reveal(RevealTarget(column: 0));

      // Assert
      expect(byRow, isFalse);
      expect(byIndex, isFalse);
      expect(byColumn, isFalse);
    });

    testWidgets('should ignore a nested table as the controller root', (
      tester,
    ) async {
      // Arrange
      final controller = RevealController();
      await tester.pumpWidget(
        _scroller(
          ExpansionTable(
            data: _table(count: 3, prefix: 'Nested')..level = 1,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      final revealed = await controller.reveal(0);

      // Assert
      expect(revealed, isFalse);
    });

    testWidgets('should detach the root when the controller changes', (
      tester,
    ) async {
      // Arrange
      final first = RevealController();
      final second = RevealController();
      final data = _table(count: 40);
      await tester.pumpWidget(
        _scroller(ExpansionTable(data: data, controller: first)),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.pumpWidget(
        _scroller(ExpansionTable(data: data, controller: second)),
      );
      await tester.pumpAndSettle();
      final viaFirst = await first.reveal(30);
      final viaSecond = await _driveFrames(tester, second.reveal(30));

      // Assert
      expect(viaFirst, isFalse);
      expect(viaSecond, isTrue);
    });

    testWidgets(
      'should wrap at most one row with a GlobalKey during and after reveal',
      (tester) async {
        // Arrange: a 200-row table so the target is far outside the viewport.
        final controller = RevealController();
        final data = _table(count: 200);
        await tester.pumpWidget(
          _scroller(
            ExpansionTable(
              data: data,
              controller: controller,
              columnWidth: 300,
            ),
            height: 400,
          ),
        );
        await tester.pumpAndSettle();

        // Act: reveal row 150.
        final future = controller.reveal(150);
        // Pump a few frames so the reveal loop starts and the slot is set.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Assert: at most one KeyedSubtree with the revealKey exists while the
        // reveal is in flight.
        final during = find.byKey(controller.revealKey);
        expect(during.evaluate().length, lessThanOrEqualTo(1));

        final revealed = await _driveFrames(tester, future);
        expect(revealed, isTrue);

        // After the reveal settles, the slot is cleared — no keyed subtree.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final after = find.byKey(controller.revealKey);
        expect(after, findsNothing);
      },
    );

    testWidgets('should reveal a row inside a nested child table', (
      tester,
    ) async {
      // Arrange: a parent table whose second row has a nested child table.
      // The child row sits far down a tall scroller so it needs revealing.
      final controller = RevealController();
      final childData = _table(count: 40, prefix: 'Kid', columns: 1);
      final data = TableData(
        header: [TableColumnData(value: 'Col 1')],
        rows: [
          TableRowData(cells: ['Root row']),
          TableRowData(cells: ['Parent row'], child: childData),
        ],
      );
      await tester.pumpWidget(
        _scroller(
          ExpansionTable(data: data, controller: controller, columnWidth: 300),
          height: 400,
        ),
      );
      await tester.pumpAndSettle();
      // Expand the parent so the child table renders.
      data.rows[1].active = true;
      await tester.pumpAndSettle();
      final target = childData.rows[30];

      // Act
      final revealed = await _driveFrames(tester, controller.reveal(target));

      // Assert
      expect(revealed, isTrue);
      expect(find.text('Kid 30 c0'), findsOneWidget);
      // The slot is cleared after the reveal.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(controller.revealKey), findsNothing);
    });
  });
}
