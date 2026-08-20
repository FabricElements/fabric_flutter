import 'package:fabric_flutter/component/input_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseValueByInputDataType', () {
    group('phone', () {
      test('should strip formatting and prefix a single plus sign', () {
        // Arrange
        const raw = '+1 (415) 555-2671';

        // Act
        final result = parseValueByInputDataType(
          type: InputDataType.phone,
          value: raw,
        );

        // Assert
        expect(result, '+14155552671');
      });

      test('should collapse existing plus signs into one prefix', () {
        // Arrange
        const raw = '++44 20 7946 0958';

        // Act
        final result = parseValueByInputDataType(
          type: InputDataType.phone,
          value: raw,
        );

        // Assert
        expect(result, '+442079460958');
      });

      test('should return null when there are no digits', () {
        // Arrange
        const raw = '+()- ';

        // Act
        final result = parseValueByInputDataType(
          type: InputDataType.phone,
          value: raw,
        );

        // Assert
        expect(result, isNull);
      });
    });

    group('numbers', () {
      test('should parse an integer value', () {
        // Arrange & Act
        final result = parseValueByInputDataType(
          type: InputDataType.int,
          value: '42',
        );

        // Assert
        expect(result, 42);
      });

      test('should parse a double value', () {
        // Arrange & Act
        final result = parseValueByInputDataType(
          type: InputDataType.double,
          value: '3.14',
        );

        // Assert
        expect(result, 3.14);
      });
    });

    test('should return null for a null value', () {
      // Arrange & Act
      final result = parseValueByInputDataType(
        type: InputDataType.phone,
        value: null,
      );

      // Assert
      expect(result, isNull);
    });
  });
}
