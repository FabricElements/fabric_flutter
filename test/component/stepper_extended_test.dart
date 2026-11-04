import 'package:fabric_flutter/component/stepper_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepperExtended', () {
    testWidgets(
      'should not throw and should route a scroll-listener callback failure '
      'to onError when provided',
      (WidgetTester tester) async {
        // Arrange
        final errors = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: StepperExtended(
                  scrollable: true,
                  onScrollOffsetChanged: (_) => throw StateError('boom offset'),
                  onError: errors.add,
                  steps: List<Step>.generate(
                    20,
                    (index) => Step(
                      title: Text('Step $index'),
                      content: SizedBox(
                        height: 100,
                        child: Text('Content $index'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: scroll the stepper to trigger its scroll listener (and the
        // throwing onScrollOffsetChanged callback).
        final controller = tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .controller!;
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();

        // Assert: the throwing callback never escapes the scroll listener,
        // and is routed to onError instead.
        expect(tester.takeException(), isNull);
        expect(errors, [
          'StepperExtended.onScrollOffsetChanged threw: Bad state: boom offset',
        ]);
      },
    );

    testWidgets(
      'should not throw and should only log when onScrollOffsetChanged '
      'throws and no onError is provided',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: StepperExtended(
                  scrollable: true,
                  onScrollOffsetChanged: (_) => throw StateError('boom offset'),
                  steps: List<Step>.generate(
                    20,
                    (index) => Step(
                      title: Text('Step $index'),
                      content: SizedBox(
                        height: 100,
                        child: Text('Content $index'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act
        final controller = tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .controller!;
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();

        // Assert
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'should render step content that measures itself without throwing',
      (WidgetTester tester) async {
        // Arrange: a LayoutBuilder and a shrink-wrapping viewport both refuse
        // to report intrinsic dimensions, so any ancestor that measures its
        // child intrinsically (an IntrinsicHeight, for example) fails during
        // layout. Step content is free to use either.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StepperExtended(
                steps: [
                  Step(
                    title: const Text('Measured'),
                    content: LayoutBuilder(
                      builder: (context, constraints) =>
                          Text('Width ${constraints.maxWidth}'),
                    ),
                  ),
                  Step(
                    title: const Text('Shrink wrapped'),
                    content: SizedBox(
                      height: 120,
                      child: ListView(
                        shrinkWrap: true,
                        children: const [Text('Listed content')],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: the content laid out and nothing was thrown.
        expect(tester.takeException(), isNull);
        expect(find.text('Listed content'), findsOneWidget);
        expect(find.textContaining('Width '), findsOneWidget);
      },
    );
  });
}
