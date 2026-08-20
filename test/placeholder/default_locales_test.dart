import 'package:fabric_flutter/placeholder/default_locales.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keys that deliberately ship English only.
///
/// These are proper nouns (social network brand names, which are not
/// translated), the lorem-ipsum placeholders (identical filler text in every
/// language), and a handful of labels that read the same in both languages.
/// Every other key must provide Spanish.
///
/// This is an *exception allowlist*, not an inventory: new keys are required to
/// be bilingual by default, so adding a key never requires touching this set.
const _englishOnlyKeys = {
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
      expect(missing, isEmpty);
    });

    test('should provide Spanish for every translatable key', () {
      // Arrange
      final missing = <String>[];

      // Act
      defaultLocales.forEach((key, translations) {
        if (_englishOnlyKeys.contains(key)) return;
        if (!translations.containsKey('es')) missing.add(key);
      });

      // Assert
      expect(missing, isEmpty);
    });

    test('should not list stale keys in the English-only exception set', () {
      // Arrange: the allowlist must describe keys that actually exist, and must
      // not retain a key that has since gained a Spanish translation.
      final stale = <String>[];

      // Act
      for (final key in _englishOnlyKeys) {
        final translations = defaultLocales[key];
        if (translations == null || translations.containsKey('es')) {
          stale.add(key);
        }
      }

      // Assert
      expect(stale, isEmpty);
    });

    test('should keep the keys the package resolves at runtime', () {
      // Arrange: a representative sample referenced directly from widgets and
      // validators. Presence is asserted rather than an exact table size, so
      // additive localization work never has to update this test.
      const required = {
        'label--continue',
        'label--cancel',
        'label--required',
        'validation--required',
        'validation--email-address',
        'validation--phone',
        'validation--username',
      };

      // Act
      final missing = required.difference(defaultLocales.keys.toSet());

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
