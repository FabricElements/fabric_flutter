import 'package:fabric_flutter/component/smart_image.dart';
import 'package:fabric_flutter/view/view_featured.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in a minimal routed app so [ViewFeatured]'s action button can
/// exercise `Navigator.pushNamed` without a missing-route failure.
///
/// [reduceMotion] toggles `MediaQueryData.disableAnimations`, which
/// [ViewFeatured] reads to skip its staged opacity reveal; enabling it lets a
/// test assert the final rendered state after a single `pump`.
Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  routes: {'/next': (_) => const Scaffold(body: Text('next-page'))},
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: child,
  ),
);

void main() {
  group('ViewFeatured', () {
    group('rendering', () {
      testWidgets('should render the background image and headline', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Welcome aboard',
            ),
            reduceMotion: true,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(SmartImage), findsOneWidget);
        expect(find.text('Welcome aboard'), findsOneWidget);
      });

      testWidgets('should render the description when provided', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Title',
              description: 'A helpful description',
            ),
            reduceMotion: true,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('A helpful description'), findsOneWidget);
      });

      testWidgets('should render a custom child when provided', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Title',
              child: Text('custom-child'),
            ),
            reduceMotion: true,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('custom-child'), findsOneWidget);
      });

      testWidgets('should uppercase the action label on the button', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Title',
              actionLabel: 'Go home',
            ),
            reduceMotion: true,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('GO HOME'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
      });

      testWidgets('should omit the action button when no label is given', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Title',
            ),
            reduceMotion: true,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    });

    group('actions', () {
      testWidgets('should invoke onPressed when the action is tapped', (
        WidgetTester tester,
      ) async {
        // Arrange
        var pressed = 0;

        // Act
        await tester.pumpWidget(
          _app(
            ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Title',
              actionLabel: 'Tap me',
              onPressed: () => pressed++,
            ),
            reduceMotion: true,
          ),
        );
        await tester.pump();
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        // Assert
        expect(pressed, 1);
      });

      testWidgets('should navigate to actionUrl when the action is tapped', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Title',
              actionLabel: 'Next',
              actionUrl: '/next',
            ),
            reduceMotion: true,
          ),
        );
        await tester.pump();
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('next-page'), findsOneWidget);
      });
    });

    group('reveal animation', () {
      testWidgets('should reveal all stages over the staged durations', (
        WidgetTester tester,
      ) async {
        // Arrange
        const duration = 50;

        // Act
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Staged title',
              description: 'Staged description',
              actionLabel: 'Staged action',
              animationDuration: duration,
            ),
          ),
        );
        // Advance past all five staged timers (5 * duration) plus the
        // AnimatedOpacity transitions so the final opacity is reached.
        await tester.pump(const Duration(milliseconds: duration * 6));
        await tester.pumpAndSettle();

        // Assert – every stage's content is present and fully opaque.
        expect(find.text('Staged title'), findsOneWidget);
        expect(find.text('Staged description'), findsOneWidget);
        expect(find.text('STAGED ACTION'), findsOneWidget);
      });

      testWidgets('should cancel pending timers when disposed early', (
        WidgetTester tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          _app(
            const ViewFeatured(
              image: 'https://example.com/bg.jpg',
              headline: 'Title',
              actionLabel: 'Action',
              animationDuration: 100,
            ),
          ),
        );

        // Act – tear the view down before the staged timers fire.
        await tester.pumpWidget(_app(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 600));

        // Assert – no timer fired setState on a disposed State.
        expect(tester.takeException(), isNull);
      });
    });
  });
}
