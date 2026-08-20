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

  group('chartRangeBounds', () {
    test('should keep the upper bound untouched when min is below max', () {
      // Arrange & Act
      final bounds = chartRangeBounds(min: 10, max: 200);

      // Assert — a valid range must be passed through unchanged. The previous
      // `if (min >= min)` guard was always true and inflated max to 310.
      expect(bounds.min, 10);
      expect(bounds.max, 200);
    });

    test('should stay stable when applied repeatedly to the same input', () {
      // Arrange — `reset()` runs on every didUpdateWidget, so a guard that
      // fires unconditionally would drift the upper bound on each rebuild.
      final first = chartRangeBounds(min: 10, max: 200);

      // Act
      final second = chartRangeBounds(min: 10, max: 200);

      // Assert
      expect(second.max, first.max);
    });

    test('should round the bounds outward to whole numbers', () {
      // Arrange & Act
      final bounds = chartRangeBounds(min: 10.7, max: 200.2);

      // Assert
      expect(bounds.min, 10);
      expect(bounds.max, 201);
    });

    test('should fall back to zero and one hundred when values are null', () {
      // Arrange & Act
      final bounds = chartRangeBounds();

      // Assert
      expect(bounds.min, 0);
      expect(bounds.max, 100);
    });

    test('should push the upper bound above an equal lower bound', () {
      // Arrange & Act
      final bounds = chartRangeBounds(min: 50, max: 50);

      // Assert — RangeSlider rejects an empty range, so max must clear min.
      expect(bounds.min, 50);
      expect(bounds.max, greaterThan(bounds.min));
    });

    test('should push the upper bound above an inverted range', () {
      // Arrange & Act
      final bounds = chartRangeBounds(min: 80, max: 20);

      // Assert
      expect(bounds.max, greaterThan(bounds.min));
    });
  });
}
