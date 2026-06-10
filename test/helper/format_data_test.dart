import 'package:fabric_flutter/helper/format_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatData.numberFormat', () {
    test('should format a value with two fractional digits and grouping', () {
      // Arrange
      final formatter = FormatData.numberFormat();

      // Act
      final result = formatter.format(1234.5);

      // Assert
      expect(result, '1,234.50');
    });
  });

  group('FormatData.numberClearFormat', () {
    test('should format an integer with grouping and no decimals', () {
      // Arrange
      final formatter = FormatData.numberClearFormat();

      // Act
      final result = formatter.format(1234);

      // Assert
      expect(result, '1,234');
    });
  });

  group('FormatData.currencyFormat', () {
    test('should format a value with the default dollar symbol', () {
      // Arrange
      final formatter = FormatData.currencyFormat();

      // Act
      final result = formatter.format(5);

      // Assert
      expect(result, '\$5.00');
    });

    test('should honor a custom currency symbol', () {
      // Arrange
      final formatter = FormatData.currencyFormat(symbol: '€');

      // Act
      final result = formatter.format(5);

      // Assert
      expect(result, '€5.00');
    });
  });

  group('FormatData.percentFormat', () {
    test('should format a fraction as a whole percentage', () {
      // Arrange
      final formatter = FormatData.percentFormat();

      // Act
      final result = formatter.format(0.5);

      // Assert
      expect(result, '50%');
    });
  });

  group('FormatData.decimalPercentFormat', () {
    test('should format a fraction with two decimal places', () {
      // Arrange
      final formatter = FormatData.decimalPercentFormat();

      // Act
      final result = formatter.format(0.5);

      // Assert
      expect(result, '50.00%');
    });
  });

  group('FormatData.formatDateShort', () {
    test('should format a date using the MM/dd/yyyy pattern', () {
      // Arrange
      final formatter = FormatData.formatDateShort();

      // Act
      final result = formatter.format(DateTime(2020, 1, 5));

      // Assert
      expect(result, '01/05/2020');
    });
  });

  group('FormatData.formatDate', () {
    test('should produce a long, human-readable date', () {
      // Arrange
      final formatter = FormatData.formatDate();

      // Act
      final result = formatter.format(DateTime(2020, 1, 5));

      // Assert
      expect(result, 'January 5, 2020');
    });
  });
}
