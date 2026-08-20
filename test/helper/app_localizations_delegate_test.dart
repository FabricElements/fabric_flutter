import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocalizations', () {
    group('get', () {
      test('should return non-key values unchanged', () {
        // Arrange
        final localizations = AppLocalizations(const Locale('en', 'US'));

        // Act
        final result = localizations.get('Plain Text');

        // Assert
        expect(result, 'Plain Text');
      });

      test('should resolve a known key to its English label', () async {
        // Arrange
        final localizations = AppLocalizations(const Locale('en', 'US'));
        await localizations.load();

        // Act
        final result = localizations.get('label--accept');

        // Assert
        expect(result, isNot('label--accept'));
        expect(result, isNotEmpty);
      });

      test(
        'should localize a known key using the active language code',
        () async {
          // Arrange
          final localizations = AppLocalizations(const Locale('es', 'ES'));
          await localizations.load();

          // Act
          final english = AppLocalizations(const Locale('en', 'US'));
          await english.load();
          final spanishLabel = localizations.get('label--accept');
          final englishLabel = english.get('label--accept');

          // Assert
          expect(spanishLabel, isNotEmpty);
          expect(spanishLabel, isNot(englishLabel));
        },
      );

      test('should normalize camelCase and underscore keys consistently', () {
        // Arrange
        final localizations = AppLocalizations(const Locale('en', 'US'));

        // Act
        final camel = localizations.get('label--myCustomKey');
        final underscore = localizations.get('label--my_custom_key');

        // Assert
        expect(camel, 'label--my-custom-key');
        expect(underscore, camel);
      });

      test('should substitute placeholder options', () async {
        // Arrange
        final localizations = AppLocalizations(const Locale('en', 'US'));
        localizations.keys = {
          'label--greeting': {'en': 'Hello {name}'},
        };
        await localizations.load();

        // Act
        final result = localizations.get('label--greeting', {
          'name': 'Copilot',
        });

        // Assert
        expect(result, 'Hello Copilot');
      });

      test('should leave unknown placeholders untouched', () async {
        // Arrange
        final localizations = AppLocalizations(const Locale('en', 'US'));
        localizations.keys = {
          'label--greeting': {'en': 'Hello {name}'},
        };
        await localizations.load();

        // Act
        final result = localizations.get('label--greeting', {'other': 'value'});

        // Assert
        expect(result, 'Hello {name}');
      });

      test('should stay stable across repeated calls', () {
        // Arrange
        final localizations = AppLocalizations(const Locale('en', 'US'));

        // Act
        final first = localizations.get('label--sampleKey');
        final second = localizations.get('label--sampleKey');

        // Assert
        expect(first, 'label--sample-key');
        expect(second, first);
      });
    });
  });
}
