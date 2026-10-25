import 'package:fabric_flutter/component/expansion_table.dart';
import 'package:fabric_flutter/component/logs_list.dart';
import 'package:fabric_flutter/component/pagination_container.dart';
import 'package:fabric_flutter/component/stepper_extended.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/scroll_reveal.dart';
import 'package:fabric_flutter/serialized/logs_data.dart';
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

/// Sizes the surface to a narrow 360 logical-pixel wide phone viewport.
void _useNarrowViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps [child] as one entry of a parent [ListView] and returns its
/// controller so tests can observe the parent's vertical offset.
Future<ScrollController> _pumpInParentList(
  WidgetTester tester,
  Widget child,
) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 120, child: Placeholder()),
            child,
            const SizedBox(height: 600, child: Placeholder()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Builds a table fixture with [count] rows over three string columns.
TableData _table({int count = 6}) => TableData(
  header: [
    for (var index = 0; index < 3; index++)
      TableColumnData(value: 'Col ${index + 1}'),
  ],
  rows: [
    for (var index = 0; index < count; index++)
      TableRowData(cells: [for (var c = 0; c < 3; c++) 'Row $index c$c']),
  ],
);

/// Builds a handful of steps for an embedded [StepperExtended].
List<Step> _steps() => [
  for (var index = 0; index < 6; index++)
    Step(title: Text('Step $index'), content: Text('Step $index body')),
];

/// Builds a handful of log entries for an embedded [LogsList].
List<LogsData> _logs() => [
  for (var index = 0; index < 6; index++)
    LogsData(
      id: 'log-$index',
      text: 'Log line $index',
      timestamp: DateTime(2024, 1, 1, 12),
    ),
];

void main() {
  group('scroll reveal embedding', () {
    group('ExpansionTable', () {
      testWidgets('should fit a 360 px parent ListView without overflow', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);

        // Act
        await _pumpInParentList(
          tester,
          ExpansionTable(data: _table(), columnWidth: 300),
        );

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.text('Col 1'), findsOneWidget);
      });

      testWidgets('should keep vertical drags on the parent ListView', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);
        final parent = await _pumpInParentList(
          tester,
          ExpansionTable(data: _table(), columnWidth: 300),
        );

        // Act
        await tester.drag(find.text('Row 2 c0'), const Offset(0, -80));
        await tester.pumpAndSettle();

        // Assert
        expect(parent.offset, greaterThan(0));
      });

      testWidgets(
        'should consume a horizontal drag without moving the parent',
        (tester) async {
          // Arrange
          _useNarrowViewport(tester);
          final parent = await _pumpInParentList(
            tester,
            ExpansionTable(data: _table(), columnWidth: 300),
          );
          final before = tester.getRect(find.text('Row 2 c0'));

          // Act
          await tester.drag(find.text('Row 2 c0'), const Offset(-120, 0));
          await tester.pumpAndSettle();

          // Assert — positive control: the table really did pan horizontally.
          expect(
            tester.getRect(find.text('Row 2 c0')).left,
            lessThan(before.left),
          );
          expect(parent.offset, 0);
        },
      );

      testWidgets('should reveal a row inside a parent ListView', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);
        final controller = RevealController();
        final data = _table(count: 30);
        final parent = await _pumpInParentList(
          tester,
          ExpansionTable(data: data, controller: controller, columnWidth: 300),
        );

        // Act
        final revealed = await _driveFrames(
          tester,
          controller.reveal(data.rows[28]),
        );

        // Assert
        expect(revealed, isTrue);
        expect(parent.offset, greaterThan(0));
        expect(tester.getRect(find.text('Row 28 c0')).top, closeTo(66.9, 12));
      });
    });

    group('PaginationContainer', () {
      testWidgets('should fit a 360 px parent ListView without overflow', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);

        // Act
        await _pumpInParentList(
          tester,
          PaginationContainer(
            embedded: true,
            items: List.generate(6, (index) => index),
            itemBuilder: (_, index, data) =>
                ListTile(title: Text('Item $data')),
          ),
        );

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.text('Item 0'), findsOneWidget);
      });

      testWidgets('should leave vertical scrolling to the parent ListView', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);
        final parent = await _pumpInParentList(
          tester,
          PaginationContainer(
            embedded: true,
            items: List.generate(6, (index) => index),
            itemBuilder: (_, index, data) =>
                ListTile(title: Text('Item $data')),
          ),
        );

        // Act
        await tester.drag(find.text('Item 2'), const Offset(0, -80));
        await tester.pumpAndSettle();

        // Assert
        expect(parent.offset, greaterThan(0));
      });

      testWidgets('should reveal an item inside a parent ListView', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);
        final controller = RevealController();
        final items = List.generate(30, (index) => index);
        final parent = await _pumpInParentList(
          tester,
          PaginationContainer(
            embedded: true,
            items: items,
            controller: controller,
            itemBuilder: (_, index, data) => SizedBox(
              height: 64,
              child: ListTile(title: Text('Item $data')),
            ),
          ),
        );

        // Act
        final revealed = await _driveFrames(tester, controller.reveal(28));

        // Assert
        expect(revealed, isTrue);
        expect(parent.offset, greaterThan(0));
        expect(tester.getRect(find.text('Item 28')).top, closeTo(73.6, 12));
      });
    });

    group('StepperExtended', () {
      testWidgets('should fit a 360 px parent ListView without overflow', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);

        // Act
        await _pumpInParentList(tester, StepperExtended(steps: _steps()));

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.text('Step 0'), findsOneWidget);
      });

      testWidgets('should reveal a step inside a parent ListView', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);
        final controller = RevealController();
        final parent = await _pumpInParentList(
          tester,
          StepperExtended(steps: _steps(), controller: controller),
        );

        // Act
        final revealed = await _driveFrames(tester, controller.reveal(5));

        // Assert
        expect(revealed, isTrue);
        expect(parent.offset, greaterThan(0));
        expect(tester.getRect(find.text('Step 5')).top, closeTo(70.8, 12));
      });
    });

    group('LogsList', () {
      testWidgets('should fit a 360 px parent ListView without overflow', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);

        // Act
        await _pumpInParentList(tester, LogsList(logs: _logs()));

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.text('Log line 0', findRichText: true), findsOneWidget);
      });

      testWidgets('should scroll the parent ListView on a vertical drag', (
        tester,
      ) async {
        // Arrange
        _useNarrowViewport(tester);
        final parent = await _pumpInParentList(tester, LogsList(logs: _logs()));

        // Act
        await tester.drag(
          find.text('Log line 2', findRichText: true),
          const Offset(0, -80),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(parent.offset, greaterThan(0));
      });
    });
  });
}
