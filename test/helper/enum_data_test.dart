import 'package:fabric_flutter/helper/enum_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample enum used to exercise [EnumData] lookups.
enum SampleStatus { active, inactive, pending }

void main() {
  group('EnumData.describe', () {
    test('should return the name portion of an enum value', () {
      // Arrange, Act & Assert
      expect(EnumData.describe(SampleStatus.active), 'active');
    });

    test('should return null for a null value', () {
      // Arrange, Act & Assert
      expect(EnumData.describe(null), isNull);
    });

    test('should return unknown for a null value in debug mode', () {
      // Arrange, Act & Assert
      expect(EnumData.describe(null, debug: true), 'unknown');
    });
  });

  group('EnumData.find', () {
    test('should resolve an enum by identity', () {
      // Arrange, Act
      final result = EnumData.find(
        enums: SampleStatus.values,
        value: SampleStatus.pending,
      );

      // Assert
      expect(result, SampleStatus.pending);
    });

    test('should resolve an enum from its string name', () {
      // Arrange, Act
      final result = EnumData.find(
        enums: SampleStatus.values,
        value: 'inactive',
      );

      // Assert
      expect(result, SampleStatus.inactive);
    });

    test('should return null when no enum matches the string', () {
      // Arrange, Act
      final result = EnumData.find(
        enums: SampleStatus.values,
        value: 'missing',
      );

      // Assert
      expect(result, isNull);
    });

    test('should return null when the value is null', () {
      // Arrange, Act & Assert
      expect(EnumData.find(enums: SampleStatus.values, value: null), isNull);
    });
  });

  group('EnumData.findFromString', () {
    test('should resolve an enum from a matching string', () {
      // Arrange, Act
      final result = EnumData.findFromString(
        enums: SampleStatus.values,
        value: 'active',
      );

      // Assert
      expect(result, SampleStatus.active);
    });

    test('should return null for an unmatched string', () {
      // Arrange, Act & Assert
      expect(
        EnumData.findFromString(enums: SampleStatus.values, value: 'nope'),
        isNull,
      );
    });
  });

  group('EnumData.match', () {
    test('should return the value when present in the enum list', () {
      // Arrange, Act & Assert
      expect(
        EnumData.match(enums: SampleStatus.values, value: SampleStatus.active),
        SampleStatus.active,
      );
    });

    test('should return the fallback when the value is absent', () {
      // Arrange, Act & Assert
      expect(
        EnumData.match(
          enums: const [SampleStatus.active],
          value: SampleStatus.pending,
          unknown: SampleStatus.inactive,
        ),
        SampleStatus.inactive,
      );
    });
  });

  group('EnumData.toList', () {
    test('should map enum values to their string names', () {
      // Arrange, Act
      final result = EnumData.toList(SampleStatus.values);

      // Assert
      expect(result, ['active', 'inactive', 'pending']);
    });
  });
}
