import 'package:fabric_flutter/component/phone_input.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
  supportedLocales: const [Locale('en', 'US')],
  home: Scaffold(body: child),
);

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

    testWidgets('should keep rendering after a parent rebuild', (tester) async {
      // Arrange — the picker options are cached in initState, so a rebuild
      // must not throw or drop the fields.
      await tester.pumpWidget(
        _wrap(const PhoneInput(value: null, country: 'US')),
      );
      await tester.pumpAndSettle();

      // Act — force a rebuild with the same configuration.
      await tester.pumpWidget(
        _wrap(const PhoneInput(value: null, country: 'US')),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(PhoneInput), findsOneWidget);
    });

    testWidgets('should show the custom validator error on a mismatch', (
      tester,
    ) async {
      // Arrange — a number that passes the built-in phone validation but is
      // rejected by the caller's custom rule.
      final formKey = GlobalKey<FormState>();
      String? received;
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: PhoneInput(
              value: null,
              country: 'US',
              validator: (value) {
                received = value;
                return 'error--custom-rule';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act — enter a valid US number and validate the form.
      await tester.enterText(
        find.byKey(const Key('phone-input')),
        '4155551234',
      );
      await tester.pumpAndSettle();
      formKey.currentState!.validate();

      // Assert
      expect(received, isNotNull);
      expect(find.text('error--custom-rule'), findsOneWidget);
    });

    testWidgets('should keep the built-in error when the input is malformed', (
      tester,
    ) async {
      // Arrange — the custom validator must not mask the built-in message.
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: PhoneInput(
              value: null,
              country: 'US',
              validator: (value) => 'error--custom-rule',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act — enter an invalid number and validate the form.
      await tester.enterText(find.byKey(const Key('phone-input')), '1');
      await tester.pumpAndSettle();
      formKey.currentState!.validate();

      // Assert — the built-in phone error wins, the custom one never appears.
      expect(find.text('error--custom-rule'), findsNothing);
      expect(find.text('Enter a valid phone number'), findsOneWidget);
    });

    testWidgets('should be unchanged when the validator is omitted', (
      tester,
    ) async {
      // Arrange — same setup as the custom-validator case but without one.
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: const PhoneInput(value: null, country: 'US'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act — enter an invalid number and validate the form.
      await tester.enterText(find.byKey(const Key('phone-input')), '1');
      await tester.pumpAndSettle();
      formKey.currentState!.validate();

      // Assert — the built-in message appears exactly as before.
      expect(find.text('Enter a valid phone number'), findsOneWidget);
    });
  });
}
