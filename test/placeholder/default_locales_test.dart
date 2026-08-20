import 'package:fabric_flutter/placeholder/default_locales.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultLocales', () {
    test('should expose a non-empty localization table', () {
      // Arrange & Act
      final entries = defaultLocales.entries;

      // Assert
      expect(entries, isNotEmpty);
    });

    test('should provide an English translation for every key', () {
      // Arrange
      final missing = <String>[];

      // Act
      defaultLocales.forEach((key, translations) {
        if (!translations.containsKey('en')) missing.add(key);
      });

      // Assert: English is the fallback language, so it must always exist.
      // Spanish is intentionally omitted for proper nouns such as brand names
      // and for the lorem-ipsum placeholders, which read the same in both.
      expect(missing, isEmpty);
    });

    test('should provide Spanish for every translatable key', () {
      // Arrange: keys that read identically in both languages.
      const englishOnly = {
        'label--id',
        'label--total',
        'label--total-label',
        'label--youtube',
        'label--vimeo',
        'lorem--s',
        'lorem--m',
        'lorem--l',
        'lorem--block',
        'label--behance',
        'label--dribbble',
        'label--facebook',
        'label--instagram',
        'label--linkedin',
        'label--tiktok',
        'label--twitter',
      };
      final missing = <String>[];

      // Act
      defaultLocales.forEach((key, translations) {
        if (englishOnly.contains(key)) return;
        if (!translations.containsKey('es')) missing.add(key);
      });

      // Assert
      expect(missing, isEmpty);
    });

    test('should never contain an empty translation', () {
      // Arrange
      final empty = <String>[];

      // Act
      defaultLocales.forEach((key, translations) {
        translations.forEach((language, value) {
          if (value.isEmpty) empty.add('$key.$language');
        });
      });

      // Assert
      expect(empty, isEmpty);
    });

    test('should namespace every key with a double dash', () {
      // Arrange
      final malformed = <String>[];

      // Act
      for (final key in defaultLocales.keys) {
        if (!key.contains('--')) malformed.add(key);
      }

      // Assert
      expect(malformed, isEmpty);
    });

    test('should keep placeholder tokens consistent across languages', () {
      // Arrange
      final mismatched = <String>[];
      final placeholder = RegExp(r'\{(\w+)\}');

      // Act
      defaultLocales.forEach((key, translations) {
        final english = translations['en'];
        final spanish = translations['es'];
        if (english == null || spanish == null) return;
        final englishTokens = placeholder
            .allMatches(english)
            .map((match) => match.group(1))
            .toSet();
        final spanishTokens = placeholder
            .allMatches(spanish)
            .map((match) => match.group(1))
            .toSet();
        if (englishTokens.length != spanishTokens.length ||
            !englishTokens.containsAll(spanishTokens)) {
          mismatched.add(key);
        }
      });

      // Assert
      expect(mismatched, isEmpty);
    });
  });
}
