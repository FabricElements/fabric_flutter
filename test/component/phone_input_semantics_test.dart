import 'package:fabric_flutter/component/phone_input.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] with a loaded localization delegate so the phone field and its
/// embedded country picker resolve their bundled labels.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// Returns the [Semantics] widgets rendered in the current tree.
Iterable<Semantics> _semantics(WidgetTester tester) =>
    tester.widgetList<Semantics>(find.byType(Semantics));

void main() {
  group('PhoneInput', () {
    group('phone-field semantics forwarding', () {
      testWidgets('should forward the semanticsLabel to the phone input', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Mobile number';

        // Act
        await _pump(tester, const PhoneInput(value: null, semanticsLabel: label));

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.label == label),
          isTrue,
        );
      });

      testWidgets('should forward the automationKey as an identifier', (
        WidgetTester tester,
      ) async {
        // Arrange
        const key = 'auth_phone_input_number';

        // Act
        await _pump(tester, const PhoneInput(value: null, automationKey: key));

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.identifier == key),
          isTrue,
        );
      });

      testWidgets('should forward the semanticHint to the phone input', (
        WidgetTester tester,
      ) async {
        // Arrange
        const hint = 'Enter the number to receive a code';

        // Act
        await _pump(tester, const PhoneInput(value: null, semanticHint: hint));

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.hint == hint),
          isTrue,
        );
      });
    });

    group('country-field semantics forwarding', () {
      testWidgets('should forward the country automationKey independently', (
        WidgetTester tester,
      ) async {
        // Arrange
        const key = 'auth_phone_input_country';

        // Act
        await _pump(tester, const PhoneInput(value: null, countryAutomationKey: key));

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.identifier == key),
          isTrue,
        );
      });
    });
  });
}
