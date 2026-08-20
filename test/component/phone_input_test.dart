import 'package:fabric_flutter/component/phone_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PhoneInput', () {
    testWidgets('should render the country and phone fields', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(const PhoneInput(value: null)));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(PhoneInput), findsOneWidget);
    });

    testWidgets('should strip grouping punctuation from typed input', (
      tester,
    ) async {
      // Arrange
      String? changed;
      await tester.pumpWidget(
        _wrap(
          PhoneInput(
            value: null,
            country: 'US',
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act — the deny formatter should reject spaces, parentheses, and dashes
      await tester.enterText(find.byKey(const Key('phone-input')), '(234) 1-2');
      await tester.pumpAndSettle();

      // Assert — only digits survive in the formatted output
      expect(changed, isNotNull);
      expect(RegExp(r'[()\s-]').hasMatch(changed!), isFalse);
    });

    testWidgets('should dispose cleanly when removed from the tree', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(const PhoneInput(value: null)));
      await tester.pumpAndSettle();

      // Act
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
    });
  });
}
