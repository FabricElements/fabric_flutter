import 'package:fabric_flutter/serialized/chart_preferences.dart';
import 'package:fabric_flutter/serialized/chart_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChartPreferences', () {
    group('constructor', () {
      test('should default the chart type to Histogram', () {
        // Arrange & Act
        final preferences = ChartPreferences();

        // Assert
        expect(preferences.type, ChartType.Histogram);
        expect(preferences.name, isNull);
        expect(preferences.hAxis, isNull);
        expect(preferences.vAxis, isNull);
      });
    });

    group('fromJson', () {
      test('should fall back to defaults for an empty payload', () {
        // Arrange & Act
        final preferences = ChartPreferences.fromJson(null);

        // Assert
        expect(preferences.type, ChartType.Histogram);
      });

      test('should deserialize axis and series mappings', () {
        // Arrange
        final json = <String, dynamic>{
          'name': 'Monthly report',
          'hAxis': 'month',
          'vAxis': 'total',
          'series1': 'region',
          'type': 'LineChart',
          'min': 0.0,
          'max': 100.0,
        };

        // Act
        final preferences = ChartPreferences.fromJson(json);

        // Assert
        expect(preferences.name, 'Monthly report');
        expect(preferences.hAxis, 'month');
        expect(preferences.vAxis, 'total');
        expect(preferences.series1, 'region');
        expect(preferences.type, ChartType.LineChart);
        expect(preferences.min, 0.0);
        expect(preferences.max, 100.0);
      });
    });

    group('toJson', () {
      test('should round-trip preferences through JSON', () {
        // Arrange
        final original = ChartPreferences(
          name: 'Report',
          hAxis: 'x',
          vAxis: 'y',
          type: ChartType.PieChart,
          min: 1.0,
          max: 5.0,
        );

        // Act
        final restored = ChartPreferences.fromJson(original.toJson());

        // Assert
        expect(restored.name, 'Report');
        expect(restored.hAxis, 'x');
        expect(restored.vAxis, 'y');
        expect(restored.type, ChartType.PieChart);
        expect(restored.min, 1.0);
        expect(restored.max, 5.0);
      });
    });
  });
}
