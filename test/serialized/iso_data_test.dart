import 'package:fabric_flutter/serialized/iso_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ISOLanguage', () {
    test('should apply default values when only alpha2 is provided', () {
      // Arrange
      final json = <String, dynamic>{'alpha2': 'en'};

      // Act
      final language = ISOLanguage.fromJson(json);

      // Assert
      expect(language.alpha2, 'en');
      expect(language.alpha3, '');
      expect(language.name, '');
      expect(language.nativeName, '');
      expect(language.emoji, '🌐');
    });

    test('should round-trip a fully populated language', () {
      // Arrange
      final language = ISOLanguage(
        alpha2: 'es',
        alpha3: 'spa',
        name: 'Spanish',
        nativeName: 'Español',
        emoji: '🇪🇸',
      );

      // Act
      final restored = ISOLanguage.fromJson(language.toJson());

      // Assert
      expect(restored.alpha2, 'es');
      expect(restored.alpha3, 'spa');
      expect(restored.name, 'Spanish');
      expect(restored.nativeName, 'Español');
      expect(restored.emoji, '🇪🇸');
    });
  });

  group('ISOCountry', () {
    test('should apply defaults for optional fields', () {
      // Arrange
      final json = <String, dynamic>{
        'countryCode': '840',
        'alpha2': 'US',
        'alpha3': 'USA',
        'name': 'United States',
      };

      // Act
      final country = ISOCountry.fromJson(json);

      // Assert
      expect(country.countryCode, '840');
      expect(country.alpha2, 'US');
      expect(country.eea, isFalse);
      expect(country.flag, '🌐');
      expect(country.capital, isNull);
      expect(country.callingCode, isNull);
    });

    test('should round-trip a fully populated country', () {
      // Arrange
      final country = ISOCountry(
        capital: 'Madrid',
        countryCode: '724',
        alpha2: 'ES',
        alpha3: 'ESP',
        name: 'Spain',
        eea: true,
        callingCode: '34',
        flag: '🇪🇸',
      );

      // Act
      final restored = ISOCountry.fromJson(country.toJson());

      // Assert
      expect(restored.capital, 'Madrid');
      expect(restored.alpha2, 'ES');
      expect(restored.eea, isTrue);
      expect(restored.callingCode, '34');
      expect(restored.flag, '🇪🇸');
    });
  });
}
