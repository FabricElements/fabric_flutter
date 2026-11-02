import 'package:fabric_flutter/component/stepper_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns every step-body [Container] — the one whose decoration carries a
/// left border — currently mounted in the tree, in layout order.
List<Container> stepBodyContainers(WidgetTester tester) {
  return tester
      .widgetList<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              ((widget.decoration as BoxDecoration).border is Border),
        ),
      )
      .toList();
}

/// Pumps a stepper whose width is [logicalWidth] logical pixels, optionally
/// nesting [inner] as the outer stepper's step content.
Future<List<Container>> _pumpAndGetStepBodies(
  WidgetTester tester,
  double logicalWidth, {
  Widget? inner,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: logicalWidth,
          child: StepperExtended(
            steps: [
              Step(
                title: const Text('Step title'),
                content: inner ?? const Text('Step content'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return stepBodyContainers(tester);
}

void main() {
  group('StepperExtended spacing', () {
    testWidgets('should use no step-body indentation on a compact width', (
      WidgetTester tester,
    ) async {
      // Arrange
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      // Act
      final bodies = await _pumpAndGetStepBodies(tester, 360);

      // Assert: a 360dp viewport is compact, so the step body keeps all of
      // its horizontal space instead of losing 64dp (32 padding + 32
      // margin) to indentation.
      expect(bodies, hasLength(1));
      expect(bodies.single.padding, EdgeInsets.zero);
      expect(bodies.single.margin, EdgeInsets.zero);
    });

    testWidgets('should not compound indentation when steppers are nested on a '
        'compact width', (WidgetTester tester) async {
      // Arrange
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final inner = StepperExtended(
        steps: const [
          Step(title: Text('Inner title'), content: Text('Inner content')),
        ],
      );

      // Act: nest a stepper inside the outer stepper's step content.
      final bodies = await _pumpAndGetStepBodies(tester, 360, inner: inner);

      // Assert: neither the outer nor the inner step body is indented,
      // so nesting never compounds lost horizontal space.
      expect(bodies, hasLength(2));
      for (final body in bodies) {
        expect(body.padding, EdgeInsets.zero);
        expect(body.margin, EdgeInsets.zero);
      }
    });

    testWidgets(
      'should keep the desktop step-body indentation on a wide width',
      (WidgetTester tester) async {
        // Arrange
        tester.view.physicalSize = const Size(2400, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        // Act
        final bodies = await _pumpAndGetStepBodies(tester, 1200);

        // Assert: medium-and-up keeps the historical 32dp padding plus 32dp
        // margin so the desktop look is unchanged.
        expect(bodies, hasLength(1));
        expect(bodies.single.padding, const EdgeInsets.only(left: 32));
        expect(bodies.single.margin, const EdgeInsets.only(left: 32));
      },
    );
  });
}
