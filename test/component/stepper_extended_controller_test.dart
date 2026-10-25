import 'package:fabric_flutter/component/stepper_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [future] to completion by pumping real frames in [step] increments.
///
/// Reveal waits on frame callbacks and on `Future.delayed` settle windows, so a
/// plain [WidgetTester.pumpAndSettle] cannot drive it.
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

/// Builds [count] steps whose titles and bodies are addressable by index.
List<Step> _steps(int count, {GlobalKey? contentKey, int contentAt = -1}) => [
  for (var i = 0; i < count; i++)
    Step(
      title: Text('Step $i'),
      content: i == contentAt
          ? SizedBox(key: contentKey, height: 40, child: Text('Body $i'))
          : Text('Body $i'),
    ),
];

/// Returns the rectangle of the step titled `Step $index`.
Rect _stepRect(WidgetTester tester, int index) =>
    tester.getRect(find.text('Step $index'));

void main() {
  group('StepperExtendedController', () {
    group('revealStep', () {
      testWidgets(
        'should scroll a far step into the viewport when scrollable',
        (tester) async {
          // Arrange: eight steps inside a 300 px tall scrollable viewport, so
          // the last steps start well outside the visible area.
          final controller = StepperExtendedController();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: StepperExtended(
                    controller: controller,
                    scrollable: true,
                    steps: _steps(8),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(_stepRect(tester, 6).top, greaterThan(300));

          // Act
          final revealed = await _driveFrames(tester, controller.revealStep(6));

          // Assert: the step is now fully inside the scrollable's viewport.
          expect(tester.takeException(), isNull);
          expect(revealed, isTrue);
          final rect = _stepRect(tester, 6);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(300));
        },
      );

      testWidgets('should scroll the parent list when not scrollable', (
        tester,
      ) async {
        // Arrange: the stepper owns no scrollable, so the reveal must move the
        // enclosing chat-like list instead. The list is non-lazy so every step
        // stays mounted and resolvable by key.
        final controller = StepperExtendedController();
        final listController = ScrollController();
        addTearDown(listController.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  controller: listController,
                  child: Column(
                    children: [
                      const SizedBox(height: 400),
                      StepperExtended(controller: controller, steps: _steps(6)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(listController.offset, 0);
        expect(_stepRect(tester, 5).top, greaterThan(300));

        // Act
        final revealed = await _driveFrames(tester, controller.revealStep(5));

        // Assert
        expect(tester.takeException(), isNull);
        expect(revealed, isTrue);
        expect(listController.offset, greaterThan(0));
        final rect = _stepRect(tester, 5);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(300));
      });

      testWidgets(
        'should reveal a control inside a step when within is given',
        (tester) async {
          // Arrange: the step body holds the keyed control the caller wants.
          final controller = StepperExtendedController();
          final contentKey = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: StepperExtended(
                    controller: controller,
                    scrollable: true,
                    steps: _steps(8, contentKey: contentKey, contentAt: 7),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Act
          final revealed = await _driveFrames(
            tester,
            controller.revealStep(7, within: contentKey),
          );

          // Assert: the keyed control, not merely the step, ended in view.
          expect(tester.takeException(), isNull);
          expect(revealed, isTrue);
          final rect = tester.getRect(find.byKey(contentKey));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(300));
        },
      );

      testWidgets('should return false for an out-of-range index', (
        tester,
      ) async {
        // Arrange
        final controller = StepperExtendedController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StepperExtended(
                controller: controller,
                scrollable: true,
                steps: _steps(3),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act & Assert
        expect(await controller.revealStep(-1), isFalse);
        expect(await controller.revealStep(3), isFalse);
      });

      testWidgets('should return false when no stepper is attached', (
        tester,
      ) async {
        // Arrange
        final controller = StepperExtendedController();

        // Act & Assert
        expect(await controller.revealStep(0), isFalse);
      });
    });

    group('stepsFromJson', () {
      test('should map maps to steps and skip non-maps', () {
        // Arrange
        final json = <dynamic>[
          {
            'title': 'One',
            'subtitle': 'Sub',
            'content': 'Body',
            'state': 'complete',
          },
          'not a map',
          {'title': 'Two'},
        ];

        // Act
        final steps = StepperExtended.stepsFromJson(json);

        // Assert
        expect(steps, hasLength(2));
        expect((steps[0].title as Text).data, 'One');
        expect((steps[0].content as Text).data, 'Body');
        expect(steps[0].state, StepState.complete);
        expect(steps[1].subtitle, isNull);
        expect(steps[1].state, StepState.indexed);
      });

      test('should return no steps for a null list', () {
        // Act & Assert
        expect(StepperExtended.stepsFromJson(null), isEmpty);
      });
    });
  });
}
