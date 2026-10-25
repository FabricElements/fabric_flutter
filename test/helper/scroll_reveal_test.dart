import 'package:fabric_flutter/helper/scroll_reveal.dart';
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
    });
  });
}
