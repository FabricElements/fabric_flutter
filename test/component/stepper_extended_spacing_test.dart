import 'package:fabric_flutter/component/stepper_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns every step-body wrapper — the [KeyedSubtree] keyed
/// `stepper_extended_step_body_<index>` — currently mounted in the tree, in
/// layout order.
List<KeyedSubtree> stepBodyWrappers(WidgetTester tester) {
  return tester
      .widgetList<KeyedSubtree>(
        find.byWidgetPredicate(
          (widget) =>
              widget is KeyedSubtree &&
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'stepper_extended_step_body_',
              ),
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
  final bodies = stepBodyWrappers(tester);
  expect(bodies, hasLength(1));
}

/// Asserts the horizontal insets the stepper must keep at every width and
/// text scale: the leading badge never touches the left viewport edge, and
/// the step content keeps the same inset from the right viewport edge as
/// the badge keeps from the left one.
void _expectInset(WidgetTester tester, double logicalWidth) {
  final badge = tester.getRect(
    find
        .byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        )
        .first,
  );
  final content = tester.renderObject<RenderParagraph>(
    find.text('Step content'),
  );
  final contentLeft = tester.getTopLeft(find.text('Step content')).dx;

  // Assert: the badge keeps at least a 4 logical pixel gutter from the
  // left viewport edge so it never touches the border.
  expect(
    badge.left,
    greaterThanOrEqualTo(4),
    reason: 'the leading badge must never touch the left screen edge',
  );
  // Assert: the text column's available width ends exactly one badge-left
  // inset from the right viewport edge, so step content keeps the same
  // gutter as the badge does and nothing runs flush against the border.
  expect(
    logicalWidth - (contentLeft + content.constraints.maxWidth),
    badge.left,
    reason:
        'the step content must keep the same inset from the right edge as '
        'the badge keeps from the left edge',
  );
}

/// Asserts the leading badge is vertically aligned with the step title: the
/// badge's center must sit within half the badge's height of the title's
/// center, so the two read as one row at every text scale.
void _expectBadgeAlignedWithTitle(WidgetTester tester) {
  final badge = tester.getRect(
    find
        .byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        )
        .first,
  );
  final title = tester.getRect(find.text('Step title'));

  expect(
    (badge.center.dy - title.center.dy).abs(),
    lessThanOrEqualTo(badge.height / 2),
    reason: 'the badge must be vertically aligned with the step title',
  );
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
      _expectInset(tester, 360);
      _expectBadgeAlignedWithTitle(tester);
    });

    testWidgets('should align title, subtitle and content at 600dp', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, 600);
      _expectAligned(tester);
      _expectInset(tester, 600);
      _expectBadgeAlignedWithTitle(tester);
    });

    testWidgets('should align title, subtitle and content at 1000dp', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, 1000);
      _expectAligned(tester);
      _expectInset(tester, 1000);
      _expectBadgeAlignedWithTitle(tester);
    });

    testWidgets('should align title, subtitle and content with large text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await _pump(tester, 360, textScale: 1.6);
      _expectAligned(tester);
      _expectInset(tester, 360);
      _expectBadgeAlignedWithTitle(tester);
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
      // One body wrapper per stepper.
      final bodies = stepBodyWrappers(tester);
      expect(bodies, hasLength(2));
    });

    testWidgets('should draw a connector segment between steps', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: StepperExtended(
                steps: const [
                  Step(title: Text('First'), content: Text('First body')),
                  Step(title: Text('Last'), content: Text('Last body')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: the first step's badge and the second step's badge are
      // joined by a connector segment whose vertical span starts at the
      // first badge's bottom and reaches the second badge's top, so the
      // rail reads as one continuous line.
      final firstBadge = tester.getRect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).shape == BoxShape.circle,
            )
            .first,
      );
      final secondBadge = tester.getRect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).shape == BoxShape.circle,
            )
            .last,
      );
      final connector = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration == null &&
              widget.constraints?.minWidth == 2,
        ),
      );
      expect(connector.top, firstBadge.bottom);
      expect(connector.bottom, secondBadge.top);
      expect(connector.left, firstBadge.center.dx - 1);
    });
  });
}
