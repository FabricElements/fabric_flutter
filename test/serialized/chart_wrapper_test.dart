import 'dart:convert';

import 'package:fabric_flutter/serialized/chart_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChartWrapperOptions', () {
    test('should apply the default histogram configuration', () {
      // Arrange & Act
      final options = ChartWrapperOptions();

      // Assert
      expect(options.histogram, {'minValue': 0, 'showItemDividers': true});
    });

    test('fromJson should treat a null payload as defaults', () {
      // Arrange & Act
      final options = ChartWrapperOptions.fromJson(null);

      // Assert
      expect(options.title, isNull);
      expect(options.histogram, isNotEmpty);
    });
  });

  group('ChartWrapperLegend', () {
    test('fromJson should treat a null payload as an empty configuration', () {
      // Arrange & Act
      final legend = ChartWrapperLegend.fromJson(null);

      // Assert
      expect(legend.position, isNull);
      expect(legend.alignment, isNull);
    });

    test('should serialize the legend position enum to its name', () {
      // Arrange
      final legend = ChartWrapperLegend(
        position: ChartWrapperLegendPosition.bottom,
      );

      // Act
      final json = legend.toJson();

      // Assert
      expect(json['position'], 'bottom');
    });
  });

  group('ChartWrapper.fromJson', () {
    test('should default to ColumnChart for an empty payload', () {
      // Arrange & Act
      final wrapper = ChartWrapper.fromJson(null);

      // Assert
      expect(wrapper.chartType, ChartType.ColumnChart);
      expect(wrapper.containerId, 'chart');
      expect(wrapper.dataTable, isEmpty);
    });

    test('should fall back to ColumnChart for an unknown chart type', () {
      // Arrange
      final json = <String, dynamic>{'chartType': 'NotARealChartType'};

      // Act
      final wrapper = ChartWrapper.fromJson(json);

      // Assert
      expect(wrapper.chartType, ChartType.ColumnChart);
    });

    test('should decode a known chart type', () {
      // Arrange
      final json = <String, dynamic>{'chartType': 'PieChart'};

      // Act
      final wrapper = ChartWrapper.fromJson(json);

      // Assert
      expect(wrapper.chartType, ChartType.PieChart);
    });
  });

  group('ChartWrapper.isValid', () {
    test('should be false when the data table is empty', () {
      // Arrange
      final wrapper = ChartWrapper(chartType: ChartType.ColumnChart);

      // Act & Assert
      expect(wrapper.isValid(), isFalse);
    });

    test('should be true for a 2x2 column chart', () {
      // Arrange
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        dataTable: [
          ['Label', 'Value'],
          ['A', 1],
        ],
      );

      // Act & Assert
      expect(wrapper.isValid(), isTrue);
    });

    test('should be false for a single-column column chart', () {
      // Arrange
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        dataTable: [
          ['Label'],
          ['A'],
        ],
      );

      // Act & Assert
      expect(wrapper.isValid(), isFalse);
    });

    test('should allow a single-column histogram', () {
      // Arrange
      final wrapper = ChartWrapper(
        chartType: ChartType.Histogram,
        dataTable: [
          ['Label'],
          ['A'],
        ],
      );

      // Act & Assert
      expect(wrapper.isValid(), isTrue);
    });
  });

  group('ChartWrapper.toJson', () {
    test('should throw when the data table is empty', () {
      // Arrange
      final wrapper = ChartWrapper(chartType: ChartType.ColumnChart);

      // Act & Assert
      expect(wrapper.toJson, throwsA(isA<Exception>()));
    });

    test('should replace NaN values with null', () {
      // Arrange
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        dataTable: [
          ['Label', 'Value'],
          ['A', double.nan],
        ],
      );

      // Act
      final json = wrapper.toJson();

      // Assert
      final table = json['dataTable'] as List;
      expect(table[1][1], isNull);
    });

    test('should replace infinite values with null', () {
      // Arrange
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        dataTable: [
          ['Label', 'Value'],
          ['A', double.infinity],
        ],
      );

      // Act
      final json = wrapper.toJson();

      // Assert
      final table = json['dataTable'] as List;
      expect(table[1][1], isNull);
    });

    test('should hide hAxis labels when there are more than 15 categories', () {
      // Arrange
      final rows = <List<dynamic>>[
        ['Label', 'Category'],
      ];
      for (var i = 0; i < 16; i++) {
        rows.add(['row$i', 'category$i']);
      }
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        options: ChartWrapperOptions(),
        dataTable: rows,
      );

      // Act
      final json = wrapper.toJson();

      // Assert
      expect(json['options']['hAxis']['textPosition'], 'none');
    });
  });

  group('ChartWrapper.encode', () {
    test('should return an empty string when options are null', () {
      // Arrange
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        dataTable: [
          ['Label', 'Value'],
          ['A', 1],
        ],
      );

      // Act & Assert
      expect(wrapper.encode(), '');
    });

    test('should produce a decodable base64 payload when options exist', () {
      // Arrange
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        options: ChartWrapperOptions(title: 'Sales'),
        dataTable: [
          ['Label', 'Value'],
          ['A', 1],
        ],
      );

      // Act
      final encoded = wrapper.encode();
      final decoded =
          jsonDecode(String.fromCharCodes(base64.decode(encoded)))
              as Map<String, dynamic>;

      // Assert
      expect(encoded, isNotEmpty);
      expect(decoded['dataTable'], isNotNull);
      expect(decoded['options']['title'], 'Sales');
    });

    test('should limit the encoded data table to the first 51 rows', () {
      // Arrange
      final rows = <List<dynamic>>[
        ['Label', 'Value'],
      ];
      for (var i = 0; i < 100; i++) {
        rows.add(['row$i', i]);
      }
      final wrapper = ChartWrapper(
        chartType: ChartType.ColumnChart,
        options: ChartWrapperOptions(),
        dataTable: rows,
      );

      // Act
      final decoded =
          jsonDecode(String.fromCharCodes(base64.decode(wrapper.encode())))
              as Map<String, dynamic>;

      // Assert
      expect((decoded['dataTable'] as List), hasLength(51));
    });
  });
}
