import 'package:fabric_flutter/component/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal app scaffolding required to pump a component.
Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
);

/// Returns the [Semantics] widgets rendered in the current tree.
Iterable<Semantics> _semantics(WidgetTester tester) =>
    tester.widgetList<Semantics>(find.byType(Semantics));

void main() {
  group('SmartImage', () {
    group('semantics', () {
      testWidgets('should expose the semanticsLabel as an image label', (
        WidgetTester tester,
      ) async {
        // Arrange
        const semanticsLabel = 'Company logo';

        // Act
        await tester.pumpWidget(
          _app(const SmartImage(url: null, semanticsLabel: semanticsLabel)),
        );

        // Assert
        expect(
          _semantics(
            tester,
          ).any((widget) => widget.properties.label == semanticsLabel),
          isTrue,
        );
      });

      testWidgets('should expose the automationKey as a semantics identifier', (
        WidgetTester tester,
      ) async {
        // Arrange
        const automationKey = 'home_header_image_logo';

        // Act
        await tester.pumpWidget(
          _app(const SmartImage(url: null, automationKey: automationKey)),
        );

        // Assert
        expect(
          _semantics(
            tester,
          ).any((widget) => widget.properties.identifier == automationKey),
          isTrue,
        );
      });

      testWidgets('should expose the semanticHint on the same node', (
        WidgetTester tester,
      ) async {
        // Arrange
        const semanticHint = 'Double tap to open the full size image';

        // Act
        await tester.pumpWidget(
          _app(const SmartImage(url: null, semanticHint: semanticHint)),
        );

        // Assert
        expect(
          _semantics(
            tester,
          ).any((widget) => widget.properties.hint == semanticHint),
          isTrue,
        );
      });

      testWidgets('should fall back to a generic label when none is given', (
        WidgetTester tester,
      ) async {
        // Act
        await tester.pumpWidget(_app(const SmartImage(url: null)));

        // Assert
        expect(
          _semantics(
            tester,
          ).any((widget) => (widget.properties.label?.isNotEmpty ?? false)),
          isTrue,
        );
      });

      testWidgets('should hide decorative images from assistive technology', (
        WidgetTester tester,
      ) async {
        // Arrange
        const semanticsLabel = 'Decorative background';

        // Act
        await tester.pumpWidget(
          _app(
            const SmartImage(
              url: null,
              semanticsLabel: semanticsLabel,
              excludeSemantics: true,
            ),
          ),
        );

        // Assert
        expect(find.byType(ExcludeSemantics), findsWidgets);
        expect(
          _semantics(
            tester,
          ).any((widget) => widget.properties.label == semanticsLabel),
          isFalse,
        );
      });
    });
  });
}
