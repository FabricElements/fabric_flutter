import 'package:fabric_flutter/component/language_picker.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] with a loaded localization delegate so the picker resolves its
/// bundled dropdown labels.
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
  group('LanguagePicker', () {
    group('semantics forwarding', () {
      testWidgets('should forward the semanticsLabel to the input node', (
        WidgetTester tester,
      ) async {
        // Arrange
        const label = 'Choose a language';

        // Act
        await _pump(
          tester,
          LanguagePicker(value: 'en', onChange: (_) {}, semanticsLabel: label),
        );

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
        const key = 'settings_locale_input_language';

        // Act
        await _pump(
          tester,
          LanguagePicker(value: 'en', onChange: (_) {}, automationKey: key),
        );

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.identifier == key),
          isTrue,
        );
      });

      testWidgets('should forward the semanticHint to the input node', (
        WidgetTester tester,
      ) async {
        // Arrange
        const hint = 'Changes the app language';

        // Act
        await _pump(
          tester,
          LanguagePicker(value: 'en', onChange: (_) {}, semanticHint: hint),
        );

        // Assert
        expect(
          _semantics(tester).any((w) => w.properties.hint == hint),
          isTrue,
        );
      });
    });
  });
}
