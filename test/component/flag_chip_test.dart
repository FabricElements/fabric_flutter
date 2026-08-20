import 'package:fabric_flutter/component/flag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FlagChip', () {
    testWidgets('should render the uppercased language code', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(const FlagChip(language: 'en')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('should format the total with grouped thousands', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        _wrap(const FlagChip(language: 'en', total: 1234567)),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('1,234,567'), findsOneWidget);
    });

    testWidgets('should omit the total when none is provided', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(const FlagChip(language: 'es')));
      await tester.pumpAndSettle();

      // Assert — only the language label is present, no numeric text.
      expect(find.text('ES'), findsOneWidget);
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('should show an info icon for the total bucket', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        _wrap(const FlagChip(language: 'total', total: 42)),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.info), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });
  });
}
