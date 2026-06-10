import 'package:fabric_flutter/helper/iso_language.dart';
import 'package:fabric_flutter/serialized/iso_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ISOLanguages.languages', () {
    test('should materialize typed languages from the raw data', () {
      // Arrange & Act
      final languages = ISOLanguages.languages;

      // Assert
      expect(languages, isNotEmpty);
      expect(languages.length, ISOLanguages.raw.length);
      expect(languages.first, isA<ISOLanguage>());
    });
  });

  group('ISOLanguages.getName', () {
    test('should return the language name for a known alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOLanguages.getName('en'), 'English');
    });

    test('should return null for an unknown alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOLanguages.getName('zz'), isNull);
    });

    test('should return null when the code is null', () {
      // Arrange, Act & Assert
      expect(ISOLanguages.getName(null), isNull);
    });
  });

  group('ISOLanguages.getEmoji', () {
    test('should return an emoji for a known alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOLanguages.getEmoji('en'), isNotNull);
    });

    test('should return null for an unknown alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOLanguages.getEmoji('zz'), isNull);
    });
  });
}
