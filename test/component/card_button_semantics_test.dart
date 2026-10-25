import 'package:fabric_flutter/component/card_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal app scaffolding required to pump a component.
Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 320, height: 320, child: child)),
);

/// Returns the [Semantics] widgets rendered in the current tree.
Iterable<Semantics> _semantics(WidgetTester tester) =>
    tester.widgetList<Semantics>(find.byType(Semantics));

void main() {
  group('CardButton', () {
    group('interaction', () {
      testWidgets('should invoke onPressed when the card is tapped', (
        WidgetTester tester,
      ) async {
        // Arrange
        var taps = 0;

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Tap me',
              onPressed: () => taps++,
            ),
          ),
        );
        await tester.tap(find.byType(CardButton));
        await tester.pump();

        // Assert
        expect(taps, 1);
      });

      testWidgets('should render headline and description text', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Headline here',
              description: 'Description here',
              onPressed: () {},
            ),
          ),
        );

        // Assert
        expect(find.text('Headline here'), findsOneWidget);
        expect(find.text('Description here'), findsOneWidget);
      });
    });

    group('semantics', () {
      testWidgets('should expose the semanticsLabel on the card node', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Open dashboard';

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Ignored headline',
              semanticsLabel: label,
              onPressed: () {},
            ),
          ),
        );

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.label == label),
          isTrue,
        );
      });

      testWidgets('should fall back to the headline when no label is given', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Fallback headline',
              onPressed: () {},
            ),
          ),
        );

        // Assert
        expect(
          _semantics(
            tester,
          ).any((w) => w.properties.label == 'Fallback headline'),
          isTrue,
        );
      });

      testWidgets('should expose the automationKey as a semantics identifier', (
        WidgetTester tester,
      ) async {
        // Arrange
        const key = 'home_grid_card_dashboard';

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Title',
              automationKey: key,
              onPressed: () {},
            ),
          ),
        );

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.identifier == key),
          isTrue,
        );
      });

      testWidgets('should expose the semanticHint on the card node', (
        WidgetTester tester,
      ) async {
        // Arrange
        const hint = 'Opens the analytics dashboard';

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Title',
              semanticHint: hint,
              onPressed: () {},
            ),
          ),
        );

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.hint == hint),
          isTrue,
        );
      });

      testWidgets('should announce the card as a button', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Dashboard',
              onPressed: () {},
            ),
          ),
        );

        // Assert
        final node = tester.getSemantics(find.byType(CardButton));
        expect(node.flagsCollection.isButton, isTrue);
        handle.dispose();
      });

      testWidgets('should merge headline and description into one node', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Reports',
              description: 'Monthly totals',
              onPressed: () {},
            ),
          ),
        );

        // Assert
        final node = tester.getSemantics(find.byType(CardButton));
        expect(node.label, 'Reports. Monthly totals');
        handle.dispose();
      });

      testWidgets('should not announce the decorative image separately', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              headline: 'Reports',
              description: 'Monthly totals',
              semanticsLabel: 'Open reports',
              semanticHint: 'Shows the monthly report',
              automationKey: 'home_grid_card_reports',
              onPressed: () {},
            ),
          ),
        );

        // Assert
        final node = tester.getSemantics(find.byType(CardButton));
        expect(node.label, 'Open reports');
        expect(node.hint, 'Shows the monthly report');
        expect(node.identifier, 'home_grid_card_reports');
        expect(node.childrenCount, 0);
        handle.dispose();
      });

      testWidgets('should satisfy the labeled tap target guideline', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          _app(
            CardButton(
              image: 'https://example.com/a.jpg',
              semanticsLabel: 'Open dashboard',
              onPressed: () {},
            ),
          ),
        );

        // Assert
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  });
}
