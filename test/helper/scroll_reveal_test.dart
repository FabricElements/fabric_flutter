import 'package:fabric_flutter/helper/scroll_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  int maxFrames = 300,
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

/// Builds a fixed-height scroll view of labelled 100 px rows.
///
/// Uses a non-lazy [SingleChildScrollView] so [keyIndex] has a mounted
/// [BuildContext] even while it sits outside the viewport — the case
/// [ScrollReveal.reveal] exists for.
Widget _list({
  required ScrollController controller,
  int count = 40,
  int? keyIndex,
  GlobalKey? key,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 300,
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          children: [
            for (var index = 0; index < count; index++)
              SizedBox(
                height: 100,
                child: Text('item $index', key: index == keyIndex ? key : null),
              ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  group('ScrollReveal', () {
    group('reveal', () {
      testWidgets('should scroll a far target into view', (tester) async {
        // Arrange
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final target = GlobalKey();
        await tester.pumpWidget(
          _list(controller: controller, keyIndex: 35, key: target),
        );
        await tester.pumpAndSettle();
        expect(controller.offset, 0);

        // Act
        final revealed = await _driveFrames(
          tester,
          ScrollReveal.reveal(target.currentContext!),
        );

        // Assert
        expect(revealed, isTrue);
        expect(controller.offset, greaterThan(0));
      });

      testWidgets(
        'should return false when the target has no enclosing scrollable',
        (tester) async {
          // Arrange
          final target = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 300,
                  height: 300,
                  child: Text('plain', key: target),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Act
          final revealed = await ScrollReveal.reveal(target.currentContext!);

          // Assert
          expect(revealed, isFalse);
        },
      );

      testWidgets('should return false when the user scrolls during a reveal', (
        tester,
      ) async {
        // Arrange
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final target = GlobalKey();
        await tester.pumpWidget(
          _list(controller: controller, keyIndex: 35, key: target),
        );
        await tester.pumpAndSettle();

        // Act
        final future = ScrollReveal.reveal(target.currentContext!);
        await tester.pump();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        final revealed = await _driveFrames(tester, future);

        // Assert
        expect(revealed, isFalse);
      });

      testWidgets('should jump without animating under reduce motion', (
        tester,
      ) async {
        // Arrange
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final target = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: _list(controller: controller, keyIndex: 35, key: target),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act
        await tester.pump();
        final revealed = await _driveFrames(
          tester,
          ScrollReveal.reveal(target.currentContext!),
        );

        // Assert
        expect(revealed, isTrue);
        expect(controller.offset, greaterThan(0));
      });

      testWidgets(
        'should stay aligned when content grows above the target after the '
        'first scroll',
        (tester) async {
          // Arrange: a spacer above the target starts collapsed and grows
          // after the first reveal, pushing the target back out of view.
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final target = GlobalKey();
          final grow = ValueNotifier<double>(0);
          addTearDown(grow.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: grow,
                          builder: (context, height, _) =>
                              SizedBox(height: height),
                        ),
                        SizedBox(height: 100, child: Text('head')),
                        SizedBox(height: 2400, child: Text('tall')),
                        SizedBox(
                          height: 100,
                          child: Text('target', key: target),
                        ),
                        const SizedBox(height: 600),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Act
          final future = ScrollReveal.reveal(target.currentContext!);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          grow.value = 600;
          await tester.pump();
          final revealed = await _driveFrames(tester, future);

          // Assert
          expect(revealed, isTrue);
          final targetBox = tester.renderObject<RenderBox>(find.byKey(target));
          final origin = targetBox.localToGlobal(Offset.zero, ancestor: null);
          expect(origin.dy, greaterThanOrEqualTo(0));
          expect(origin.dy + targetBox.size.height, lessThanOrEqualTo(300));
        },
      );

      testWidgets('should cancel an in-flight reveal when a new one starts', (
        tester,
      ) async {
        // Arrange
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final first = GlobalKey();
        final second = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      for (var index = 0; index < 40; index++)
                        SizedBox(
                          height: 100,
                          child: Text(
                            'item $index',
                            key: index == 5
                                ? first
                                : index == 35
                                ? second
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: the second reveal supersedes the first while it is still
        // settling, so the first must give up.
        final firstFuture = ScrollReveal.reveal(first.currentContext!);
        await tester.pump();
        final secondFuture = ScrollReveal.reveal(second.currentContext!);
        final firstResult = await _driveFrames(tester, firstFuture);
        final secondResult = await _driveFrames(tester, secondFuture);

        // Assert
        expect(firstResult, isFalse);
        expect(secondResult, isTrue);
        final box = tester.renderObject<RenderBox>(find.byKey(second));
        final origin = box.localToGlobal(Offset.zero, ancestor: null);
        expect(origin.dy, greaterThanOrEqualTo(0));
        expect(origin.dy + box.size.height, lessThanOrEqualTo(300));
      });

      testWidgets(
        'should reveal a target nested inside a vertical scroll view',
        (tester) async {
          // Arrange: a target taller than its enclosing inner list, itself
          // inside an outer list. Both scrollables have to move, and the inner
          // one cannot satisfy the alignment on its own — this is the shape
          // that exposes a wrong rect projection in the alignment check.
          final outer = ScrollController();
          final inner = ScrollController();
          addTearDown(outer.dispose);
          addTearDown(inner.dispose);
          final target = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    controller: outer,
                    child: Column(
                      children: [
                        const SizedBox(height: 600),
                        SizedBox(
                          height: 300,
                          child: SingleChildScrollView(
                            controller: inner,
                            child: Column(
                              children: [
                                const SizedBox(height: 800),
                                SizedBox(
                                  height: 2000,
                                  child: Text('nested target', key: target),
                                ),
                                const SizedBox(height: 200),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 600),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Act
          final revealed = await _driveFrames(
            tester,
            ScrollReveal.reveal(target.currentContext!),
          );

          // Assert: the reveal converges instead of reporting failure because
          // an unreachable offset was demanded, and the target really is in
          // the outer viewport.
          expect(revealed, isTrue);
          expect(outer.offset, greaterThan(0));
          expect(inner.offset, greaterThan(0));
          final box = tester.renderObject<RenderBox>(find.byKey(target));
          final origin = box.localToGlobal(Offset.zero, ancestor: null);
          expect(origin.dy, lessThanOrEqualTo(0));
          expect(origin.dy + box.size.height, greaterThanOrEqualTo(300));
        },
      );

      testWidgets(
        'should align a target near the bottom of a nested inner scrollable '
        'inside an outer scrollable',
        (tester) async {
          // Arrange: an inner vertical list (fixed height 200) inside an outer
          // vertical list. The target sits near the bottom of a tall inner
          // list, and the inner viewport is near the bottom of the outer list.
          // The old code intersected rects from two coordinate spaces, which
          // produced a wrong offset and caused the reveal to fail.
          final outer = ScrollController();
          final inner = ScrollController();
          addTearDown(outer.dispose);
          addTearDown(inner.dispose);
          final target = GlobalKey();
          const alignment = 0.1;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  child: SingleChildScrollView(
                    controller: outer,
                    child: Column(
                      children: [
                        const SizedBox(height: 800),
                        SizedBox(
                          height: 200,
                          child: SingleChildScrollView(
                            controller: inner,
                            child: Column(
                              children: [
                                const SizedBox(height: 1200),
                                SizedBox(
                                  height: 100,
                                  child: Text('nested target', key: target),
                                ),
                                const SizedBox(height: 200),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 600),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Act
          final revealed = await _driveFrames(
            tester,
            ScrollReveal.reveal(
              target.currentContext!,
              alignment: alignment,
            ),
          );

          // Assert: the reveal converges. Each scrollable level independently
          // applies the alignment via getOffsetToReveal, which computes
          //   offset = rectTop - alignment * (viewportExtent - rectHeight).
          // For the inner viewport (200 px, target 100 px):
          //   1200 - 0.1 * (200 - 100) = 1190.
          // For the outer viewport (400 px, inner viewport 200 px):
          //   800 - 0.1 * (400 - 200) = 780.
          expect(revealed, isTrue);
          expect((inner.offset - 1190).abs(), lessThanOrEqualTo(2),
              reason: 'inner viewport alignment');
          expect((outer.offset - 780).abs(), lessThanOrEqualTo(2),
              reason: 'outer viewport alignment');
        },
      );

      testWidgets(
        'should align a target in a horizontal inner scrollable inside a '
        'vertical outer scrollable',
        (tester) async {
          // Arrange: a horizontal inner list inside a vertical outer list.
          // The target sits far to the right of the inner list, and the inner
          // viewport is far down the outer list.
          final outer = ScrollController();
          final inner = ScrollController();
          addTearDown(outer.dispose);
          addTearDown(inner.dispose);
          final target = GlobalKey();
          const alignment = 0.1;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  child: SingleChildScrollView(
                    controller: outer,
                    child: Column(
                      children: [
                        const SizedBox(height: 800),
                        SizedBox(
                          height: 100,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: inner,
                            child: Row(
                              children: [
                                const SizedBox(width: 1200),
                                SizedBox(
                                  width: 100,
                                  child: Text('h-target', key: target),
                                ),
                                const SizedBox(width: 200),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 600),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Act
          final revealed = await _driveFrames(
            tester,
            ScrollReveal.reveal(
              target.currentContext!,
              alignment: alignment,
            ),
          );

          // Assert: the reveal converges. The inner horizontal scrollable
          // cannot reach the requested 0.1 alignment because the target sits
          // at x=1200 in 1500 px of content inside an 800 px viewport, so
          // maxScrollExtent is 700 and the offset is clamped there. The outer
          // vertical scrollable places the inner viewport so the target lands
          // at alignment 0.1 within 2 px.
          // Outer (vertical, 400 px viewport, target ~40 px tall):
          //   targetTop ≈ 830 (800 + ~30), so
          //   830 - 0.1 * (400 - 40) = 794.
          expect(revealed, isTrue);
          expect(inner.offset, greaterThanOrEqualTo(inner.position.maxScrollExtent - 2),
              reason: 'inner horizontal at maxScrollExtent');
          expect((outer.offset - 794).abs(), lessThanOrEqualTo(2),
              reason: 'outer vertical alignment');
        },
      );

      testWidgets('should not keep scheduling frames on a settled page', (
        tester,
      ) async {
        // Arrange: a short page that already shows the target at the very top,
        // so the reveal has nothing to do.
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final target = GlobalKey();
        await tester.pumpWidget(
          _list(controller: controller, count: 2, keyIndex: 0, key: target),
        );
        await tester.pumpAndSettle();
        final offsetBefore = controller.offset;

        // Act
        final future = ScrollReveal.reveal(target.currentContext!);
        final revealed = await _driveFrames(tester, future);
        await tester.pump(const Duration(milliseconds: 600));

        // Assert: the reveal resolved without moving the page, and nothing was
        // left pending once it ended.
        expect(revealed, isTrue);
        expect(controller.offset, offsetBefore);
        expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
      });
    });
  });
}
