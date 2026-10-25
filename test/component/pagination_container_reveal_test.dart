import 'dart:async';

import 'package:fabric_flutter/component/pagination_container.dart';
import 'package:fabric_flutter/helper/scroll_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake paged source that follows the container's data contract.
///
/// [Paginate] requests a page, but the container only learns about new items
/// when the caller pushes a fresh snapshot through its stream — a page request
/// carries no data of its own. This source appends one page per request and
/// exposes the accumulated snapshot to push.
class _PagedSource {
  /// Creates a source seeded with [initialItems] that appends one generated
  /// page of ten items per request.
  _PagedSource({required List<int> initialItems})
    : items = List<int>.of(initialItems);

  /// The accumulated snapshot, pushed to [controller] after each request.
  final List<int> items;

  /// Number of items appended per page request.
  static const int pageSize = 10;

  /// Value the first generated page starts from.
  static const int startAt = 100;

  /// The broadcast channel the container listens to.
  final StreamController<List<int>> controller =
      StreamController<List<int>>.broadcast();

  /// Number of pages requested so far.
  var requests = 0;

  /// Whether the source has been exhausted, so the container sees a terminal
  /// empty page instead of growing forever.
  var exhausted = false;

  /// Appends one page (unless [exhausted]) and returns a snapshot to push.
  List<int> next() {
    requests++;
    if (!exhausted) {
      final base = startAt * requests;
      items.addAll([for (var i = 0; i < pageSize; i++) base + i]);
    }
    return List<int>.of(items);
  }
}

/// Drives [future] to completion by pumping real frames in [step] increments.
///
/// The reveal loop advances one frame at a time and waits on `Future.delayed`
/// inside each page request, so a plain [WidgetTester.pumpAndSettle] cannot
/// drive it.
Future<bool?> _driveFrames(
  WidgetTester tester,
  Future<bool> future, {
  Duration step = const Duration(milliseconds: 100),
  int maxFrames = 500,
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

/// Builds a fixed-height paginated list wired to [source].
///
/// [height] sets the viewport so items of a known extent make scrolling
/// predictable, and [embedded] exercises the parent-owned scroll variant.
Widget _pagedList({
  required RevealController controller,
  required _PagedSource source,
  double height = 300,
  bool embedded = false,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: height,
      child: PaginationContainer(
        controller: controller,
        initialData: source.items.toList(),
        stream: source.controller.stream,
        embedded: embedded,
        itemBuilder: (context, index, data) =>
            SizedBox(height: 100, child: Text('item $data')),
        paginate: () async {
          final snapshot = source.next();
          source.controller.add(snapshot);
          return snapshot;
        },
      ),
    ),
  ),
);

void main() {
  group('PaginationContainer reveal', () {
    group('reveal with an index', () {
      testWidgets('should load further pages until the index is loaded', (
        tester,
      ) async {
        // Arrange: four pages of ten are needed to cover index 35.
        final source = _PagedSource(
          initialItems: List<int>.generate(10, (index) => index),
        );
        addTearDown(source.controller.close);
        final controller = RevealController();
        await tester.pumpWidget(
          _pagedList(controller: controller, source: source),
        );
        await tester.pumpAndSettle();

        // Act
        final revealed = await _driveFrames(tester, controller.reveal(35));

        // Assert
        expect(tester.takeException(), isNull);
        expect(revealed, isTrue);
        expect(source.requests, greaterThanOrEqualTo(3));
        expect(source.items.length, greaterThanOrEqualTo(40));
        expect(find.text('item ${source.items[35]}'), findsOneWidget);
      });

      testWidgets(
        'should give up after the page budget when the index is unreachable',
        (tester) async {
          // Arrange: the list grows by one page per request forever, so an index
          // beyond the reachable range must give up after the page budget.
          final source = _PagedSource(
            initialItems: List<int>.generate(10, (index) => index),
          );
          addTearDown(source.controller.close);
          final controller = RevealController();
          await tester.pumpWidget(
            _pagedList(controller: controller, source: source),
          );
          await tester.pumpAndSettle();

          // Act
          final revealed = await _driveFrames(tester, controller.reveal(9999));

          // Assert
          expect(revealed, isFalse);
          expect(source.requests, lessThanOrEqualTo(5));
          expect(source.items.length, lessThan(9999));
        },
      );

      testWidgets('should return false for a negative index', (tester) async {
        // Arrange
        final source = _PagedSource(
          initialItems: List<int>.generate(10, (index) => index),
        );
        addTearDown(source.controller.close);
        final controller = RevealController();
        await tester.pumpWidget(
          _pagedList(controller: controller, source: source),
        );
        await tester.pumpAndSettle();

        // Act
        final revealed = await controller.reveal(-1);

        // Assert
        expect(revealed, isFalse);
        expect(source.requests, 0);
        expect(find.text('item 0'), findsOneWidget);
      });

      testWidgets('should return false when no container is attached', (
        tester,
      ) async {
        // Arrange
        final controller = RevealController();

        // Act & Assert
        expect(await controller.reveal(0), isFalse);
      });
    });

    group('reveal with a predicate', () {
      testWidgets('should load further pages until a later item matches', (
        tester,
      ) async {
        // Arrange: the match only exists on the fourth page.
        final source = _PagedSource(
          initialItems: List<int>.generate(10, (index) => index),
        );
        addTearDown(source.controller.close);
        final controller = RevealController();
        await tester.pumpWidget(
          _pagedList(controller: controller, source: source),
        );
        await tester.pumpAndSettle();

        // Act
        final revealed = await _driveFrames(
          tester,
          controller.reveal((item) => item == 402),
        );

        // Assert
        expect(tester.takeException(), isNull);
        expect(revealed, isTrue);
        expect(source.requests, greaterThanOrEqualTo(4));
        expect(source.items, contains(402));
        expect(find.text('item 402'), findsOneWidget);
      });

      testWidgets(
        'should return false when nothing matches within the page budget',
        (tester) async {
          // Arrange
          final source = _PagedSource(
            initialItems: List<int>.generate(10, (index) => index),
          );
          addTearDown(source.controller.close);
          final controller = RevealController();
          await tester.pumpWidget(
            _pagedList(controller: controller, source: source),
          );
          await tester.pumpAndSettle();

          // Act
          final revealed = await _driveFrames(
            tester,
            controller.reveal((item) => item == 99999),
          );

          // Assert
          expect(revealed, isFalse);
          expect(source.requests, lessThanOrEqualTo(5));
        },
      );

      testWidgets(
        'should reveal the right item in a list that is prepended to',
        (tester) async {
          // Arrange: the list is newest-first, so a new item lands at the front
          // and every existing index shifts by one. The slot is a predicate, so
          // it must follow the item rather than the index.
          final source = _PagedSource(
            initialItems: List<int>.generate(20, (index) => 20 - index),
          );
          addTearDown(source.controller.close);
          final controller = RevealController();
          await tester.pumpWidget(
            _pagedList(controller: controller, source: source, height: 300),
          );
          await tester.pumpAndSettle();

          // Act: reveal an existing item, then push a prepended snapshot while
          // the list is being addressed.
          final future = controller.reveal((item) => item == 5);
          await tester.pump();
          source.items.insert(0, 777);
          source.controller.add(List<int>.of(source.items));
          await tester.pump();
          final revealed = await _driveFrames(tester, future);

          // Assert: the item moved one slot down but is still the revealed one.
          expect(tester.takeException(), isNull);
          expect(revealed, isTrue);
          expect(source.items[0], 777);
          final box = tester.renderObject<RenderBox>(find.text('item 5'));
          final origin = box.localToGlobal(Offset.zero, ancestor: null);
          expect(origin.dy, greaterThanOrEqualTo(0));
          expect(origin.dy + box.size.height, lessThanOrEqualTo(300));
        },
      );
    });

    group('reveal slot', () {
      testWidgets('should wrap at most one item in a key during a reveal', (
        tester,
      ) async {
        // Arrange
        final source = _PagedSource(
          initialItems: List<int>.generate(10, (index) => index),
        );
        addTearDown(source.controller.close);
        final controller = RevealController();
        await tester.pumpWidget(
          _pagedList(controller: controller, source: source),
        );
        await tester.pumpAndSettle();

        // The container's own rows are the only [KeyedSubtree]s under its
        // [ListView]; counting them keeps framework-internal subtrees out.
        int keyedRows() => tester
            .widgetList<KeyedSubtree>(
              find.descendant(
                of: find.byType(ListView),
                matching: find.byType(KeyedSubtree),
              ),
            )
            .where((widget) => widget.key is GlobalKey)
            .length;

        // Act
        final future = controller.reveal(35);
        var maxKeyed = 0;
        var completed = false;
        future.then((_) => completed = true);
        for (var i = 0; i < 200 && !completed; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final keyed = keyedRows();
          if (keyed > maxKeyed) maxKeyed = keyed;
        }
        expect(await future, isTrue);

        // Assert: never more than one keyed item, and none after the reveal.
        expect(maxKeyed, 1);
        expect(keyedRows(), 0);
      });
    });
  });
}
