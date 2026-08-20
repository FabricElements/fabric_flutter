import 'package:fabric_flutter/component/section_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects every [TextSpan] in [root] into a flat list for inspection.
List<TextSpan> _flatten(InlineSpan root) {
  final spans = <TextSpan>[];
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      spans.add(span);
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
    }
  }

  visit(root);
  return spans;
}

void main() {
  group('SectionTitle', () {
    testWidgets(
      'should highlight brace-marked segments with the primary color',
      (tester) async {
        // Arrange
        const primary = Color(0xFF00FF00);
        final theme = ThemeData(
          colorScheme: const ColorScheme.light(primary: primary),
        );

        // Act
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: SectionTitle(headline: 'Plain {emphasis} tail'),
            ),
          ),
        );

        // Assert
        final richText = tester.widget<RichText>(find.byType(RichText).first);
        final spans = _flatten(richText.text);
        final emphasis = spans.firstWhere(
          (span) => span.text?.trim() == 'emphasis',
        );
        expect(emphasis.style?.color, primary);
        final plain = spans.firstWhere(
          (span) => span.text?.contains('Plain') == true,
        );
        expect(plain.style?.color, isNot(primary));
      },
    );

    testWidgets('should render text without markers as a single span', (
      tester,
    ) async {
      // Arrange
      const headline = 'No markers here';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionTitle(headline: headline)),
        ),
      );

      // Assert
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final spans = _flatten(richText.text);
      expect(spans.any((span) => span.text == headline), isTrue);
    });
  });
}
