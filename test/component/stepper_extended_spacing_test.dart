import 'package:fabric_flutter/component/stepper_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns every step-body [Container] — the one whose foreground
/// decoration carries a left border — currently mounted in the tree, in
/// layout order.
List<Container> stepBodyContainers(WidgetTester tester) {
  return tester
      .widgetList<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.foregroundDecoration is BoxDecoration &&
              ((widget.foregroundDecoration as BoxDecoration).border is Border),
        ),
      )
      .toList();
}

/// Pumps a stepper whose width is [logicalWidth] logical pixels, optionally
/// nesting [inner] as the outer stepper's step content.
Future<void> _pump(
  WidgetTester tester,
  double logicalWidth, {
  Widget? inner,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: logicalWidth,
            child: StepperExtended(
              steps: [
                Step(
                  title: const Text('Step title'),
                  subtitle: const Text('Step subtitle'),
                  content: inner ?? const Text('Step content'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Asserts that the step title, subtitle, and content share one left edge.
void _expectAligned(WidgetTester tester) {
  final titleLeft = tester.getTopLeft(find.text('Step title')).dx;
  final subtitleLeft = tester.getTopLeft(find.text('Step subtitle')).dx;
  final contentLeft = tester.getTopLeft(find.text('Step content')).dx;
  expect(
    titleLeft,
    contentLeft,
    reason: 'the step title must share the content left edge',
  );
  expect(
    subtitleLeft,
    contentLeft,
    reason: 'the step subtitle must share the content left edge',
  );
  final bodies = stepBodyContainers(tester);
  expect(bodies, hasLength(1));
  // The body wrapper must not add indentation of its own; unset padding and
  // margin both mean zero.
  expect(bodies.single.padding, isNull);
  expect(bodies.single.margin, isNull);
}

void main() {
  group('StepperExtended spacing', () {
    testWidgets('should align title, subtitle and content on compact width', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, 360);
      _expectAligned(tester);
    });

    testWidgets('should align title, subtitle and content at 600dp', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, 600);
      _expectAligned(tester);
    });

    testWidgets('should align title, subtitle and content at 1000dp', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, 1000);
      _expectAligned(tester);
    });

    testWidgets('should align title, subtitle and content with large text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, 360, textScale: 1.6);
      _expectAligned(tester);
    });

    testWidgets('should not compound indentation when steppers are nested on a '
        'compact width', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final inner = StepperExtended(
        steps: const [
          Step(
            title: Text('Inner title'),
            subtitle: Text('Inner subtitle'),
            content: Text('Inner content'),
          ),
        ],
      );

      await _pump(tester, 360, inner: inner);

      // Assert: the inner stepper's title, subtitle and content share one
      // left edge — no width-responsive indent exists, so nesting cannot
      // compound lost horizontal space. The inner stepper sits directly in
      // the outer step's body, so this is also the outer content's edge.
      final innerContentLeft = tester.getTopLeft(find.text('Inner content')).dx;
      expect(tester.getTopLeft(find.text('Inner title')).dx, innerContentLeft);
      expect(
        tester.getTopLeft(find.text('Inner subtitle')).dx,
        innerContentLeft,
      );
      // One body wrapper per stepper: neither may add indentation.
      final bodies = stepBodyContainers(tester);
      expect(bodies, hasLength(2));
      for (final body in bodies) {
        expect(body.padding, isNull);
        expect(body.margin, isNull);
      }
    });
  });
}
