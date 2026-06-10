import 'package:fabric_flutter/helper/iso_countries.dart';
import 'package:fabric_flutter/serialized/iso_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ISOCountries.countries', () {
    test('should materialize typed countries from the raw data', () {
      // Arrange & Act
      final countries = ISOCountries.countries;

      // Assert
      expect(countries, isNotEmpty);
      expect(countries.length, ISOCountries.raw.length);
      expect(countries.first, isA<ISOCountry>());
    });

    test('should include the United States', () {
      // Arrange & Act
      final us = ISOCountries.countries
          .where((country) => country.alpha2 == 'US')
          .toList();

      // Assert
      expect(us, hasLength(1));
      expect(us.first.name, 'United States');
    });
  });

  group('ISOCountries.countriesForMobile', () {
    test('should only include countries that have a calling code', () {
      // Arrange & Act
      final mobile = ISOCountries.countriesForMobile;

      // Assert
      expect(mobile, isNotEmpty);
      expect(mobile.every((country) => country.callingCode != null), isTrue);
    });

    test('should place a primary market country first', () {
      // Arrange & Act
      final mobile = ISOCountries.countriesForMobile;

      // Assert
      expect(['US', 'CA', 'CO'], contains(mobile.first.alpha2));
    });
  });

  group('ISOCountries.getName', () {
    test('should return the country name for a known alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOCountries.getName('US'), 'United States');
    });

    test('should return null for an unknown alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOCountries.getName('ZZ'), isNull);
    });

    test('should return null when the code is null', () {
      // Arrange, Act & Assert
      expect(ISOCountries.getName(null), isNull);
    });
  });

  group('ISOCountries.getFlag', () {
    test('should return a flag emoji for a known alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOCountries.getFlag('US'), isNotNull);
    });

    test('should return null for an unknown alpha2 code', () {
      // Arrange, Act & Assert
      expect(ISOCountries.getFlag('ZZ'), isNull);
    });
  });
}
