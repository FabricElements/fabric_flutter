import 'package:fabric_flutter/component/google_chart_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chartRangeLabel', () {
    test('should format small integers without grouping separators', () {
      // Arrange, Act & Assert
      expect(chartRangeLabel(0), '0');
      expect(chartRangeLabel(42), '42');
    });

    test('should group thousands in larger values', () {
      // Arrange, Act & Assert
      expect(chartRangeLabel(1000), '1,000');
      expect(chartRangeLabel(1234567), '1,234,567');
    });

    test('should return identical output across repeated calls', () {
      // Arrange & Act — the shared formatter must stay stateless between calls.
      final first = chartRangeLabel(2048);
      final second = chartRangeLabel(2048);

      // Assert
      expect(first, second);
      expect(first, '2,048');
    });
  });
}
