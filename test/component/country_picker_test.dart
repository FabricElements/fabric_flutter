import 'package:fabric_flutter/component/country_picker.dart';
import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] with a loaded localization delegate so dropdown labels
/// resolve to their bundled strings.
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

void main() {
  group('CountryPicker', () {
    testWidgets('renders an InputData dropdown showing the selected country', (
      tester,
    ) async {
      // Arrange & Act
      await _pump(tester, CountryPicker(value: 'US', onChange: (_) {}));

      // Assert – the resolved label ends with the selected alpha-2 code.
      expect(find.byType(InputData), findsOneWidget);
      expect(find.textContaining('(US)'), findsOneWidget);
    });

    testWidgets('honors phoneNumberOrigin without throwing', (tester) async {
      // Arrange & Act
      await _pump(
        tester,
        CountryPicker(value: 'US', phoneNumberOrigin: true, onChange: (_) {}),
      );

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(InputData), findsOneWidget);
      expect(find.textContaining('(US)'), findsOneWidget);
    });
  });
}
