import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'chart_wrapper.g.dart';

// ignore_for_file: constant_identifier_names

/// Chart types supported by Google Charts
/// See: https://developers.google.com/chart/interactive/docs/gallery
enum ChartType {
  Table,
  PieChart,
  ColumnChart,
  Histogram,
  ComboChart,
  ScatterChart,
  Timeline,
}

/// Legend position options
/// See: https://developers.google.com/chart/interactive/docs/gallery/linechart#configuration-options
enum ChartWrapperLegendPosition {
  bottom,
  left,
  // 'in',
  none,
  right,
  top,
}

/// Legend alignment options
/// See: https://developers.google.com/chart/interactive/docs/gallery/linechart#configuration-options
enum ChartWrapperLegendAlignment { center, end, start }

/// Chart orientation options
/// See: https://developers.google.com/chart/interactive/docs/gallery/barchart#configuration-options
enum ChartWrapperOrientation { horizontal, vertical }

/// ChartWrapper legend options
/// See: https://developers.google.com/chart/interactive/docs/gallery/linechart#configuration-options
@JsonSerializable(explicitToJson: true)
class ChartWrapperLegend {
  @JsonKey(includeIfNull: false)
  final ChartWrapperLegendPosition? position;
  @JsonKey(includeIfNull: false)
  final ChartWrapperLegendAlignment? alignment;
  @JsonKey(disallowNullValue: false)
  final int? maxLines;
  @JsonKey(disallowNullValue: false)
  final int? pageIndex;

  @JsonKey(includeIfNull: false)
  final Map<String, String>? textStyle;

  ChartWrapperLegend({
    this.position,
    this.alignment,
    this.maxLines,
    this.pageIndex,
    this.textStyle,
  });

  factory ChartWrapperLegend.fromJson(Map<String, dynamic>? json) =>
      _$ChartWrapperLegendFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$ChartWrapperLegendToJson(this);
}

/// ChartWrapper options
/// See: https://developers.google.com/chart/interactive/docs/gallery
/// and https://developers.google.com/chart/interactive/docs/reference#configuration-options
@JsonSerializable(explicitToJson: true)
class ChartWrapperOptions {
  @JsonKey(includeIfNull: true)
  final String? title;
  @JsonKey(includeIfNull: true)
  final Map<String, String>? vAxis;
  @JsonKey(includeIfNull: true)
  final Map<String, String>? hAxis;
  @JsonKey(includeIfNull: true)
  final String? seriesType;
  @JsonKey(includeIfNull: true)
  final Map<int, Map<String, String>>? series;
  final Map<String, dynamic> histogram;
  final List<String>? colors;
  final Map<String, dynamic>? timeline;
  final Map<String, dynamic>? chartArea;


  ChartWrapperOptions({
    this.title,
    this.vAxis,
    this.hAxis,
    this.seriesType,
    this.series,
    this.histogram = const {'minValue': 0, 'showItemDividers': true},
    this.colors,
    this.timeline,
    this.chartArea,
  });

  factory ChartWrapperOptions.fromJson(Map<String, dynamic>? json) =>
      _$ChartWrapperOptionsFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$ChartWrapperOptionsToJson(this);
}

/// ChartWrapper serialized data
/// Used to store chart configuration and data
/// See: https://developers.google.com/chart/interactive/docs/reference#chartwrapperobject
@JsonSerializable(explicitToJson: true)
class ChartWrapper {
  @JsonKey(disallowNullValue: true)
  final ChartType chartType;
  @JsonKey(disallowNullValue: true)
  final ChartWrapperOptions? options;
  @JsonKey(includeIfNull: true)
  final List<List<dynamic>> dataTable;

  @JsonKey(includeIfNull: false)
  final ChartWrapperLegend? legend;

  final bool reverseCategories;
  @JsonKey(includeIfNull: false)
  final ChartWrapperOrientation? orientation;

  final String containerId;

  ChartWrapper({
    required this.chartType,
    this.options,
    this.dataTable = const [],
    this.containerId = 'chart',
    this.legend,
    this.reverseCategories = false,
    this.orientation,
  });

  factory ChartWrapper.fromJson(Map<String, dynamic>? json) =>
      _$ChartWrapperFromJson(json ?? {});

  Map<String, dynamic> toJson() {
    /// Convert the ChartWrapper to a Map
    Map<String, dynamic> baseData = _$ChartWrapperToJson(this);

    /// force this validation for baseData[dataTable] any row, except for the first one: value.isInfinite || value.isNaN ? 0 : value
    /// this is because the google charts library does not support infinite or NaN values
    if (dataTable.isEmpty) throw Exception('dataTable is empty');

    /// Handle header row
    dataTable[0] = dataTable[0]
        .map((e) => e is Map ? e : e.toString())
        .toList();

    /// Handle numerical values
    /// First element of each row is string, the rest are int
    for (int i = 0; i < dataTable.length; i++) {
      for (int j = 0; j < dataTable[i].length; j++) {
        var value = dataTable[i][j];
        // Try to parse the value as num
        // if fails, set to null
        final numValue = num.tryParse(value.toString());
        if (numValue != null) {
          // Convert to int, if infinite or NaN set to 0
          dataTable[i][j] = (numValue.isFinite && !numValue.isNaN)
              ? numValue
              : null;
        } else {
          // If not a number, convert to string
          dataTable[i][j] = value.toString();
        }
        // // if value is a date string, convert to this format: new Date(YYYY, MM, DD, HH, mm, ss)
        // final date = DateTime.tryParse(value.toString());
        // if (date != null) {
        //   dataTable[i][j] = 'new Date(${date.millisecondsSinceEpoch})';
        // }
      }
    }
    // Update the baseData with the validated dataTable
    baseData['dataTable'] = dataTable;
    // Count number of unique values on the second column
    final uniqueValues = <dynamic>{};
    for (int i = 1; i < dataTable.length; i++) {
      if (dataTable[i].length > 1) {
        uniqueValues.add(dataTable[i][1]);
      }
    }
    // If more than 20 unique values, hide histogram hAxis labels
    if (uniqueValues.length > 15) {
      baseData['options']['hAxis'] ??= {};
      baseData['options']['hAxis']['textPosition'] = 'none';
    }
    return baseData;
  }

  /// Encode the chart as a JSON string base64 encoded
  String encode() {
    if (options == null) return '';

    /// Convert the ChartWrapper to a Map
    Map<String, dynamic> baseData = toJson();
    // Convert the baseData to JSON string
    final jsonString = jsonEncode(baseData);
    // Base 64 encode the JSON string
    final encoded = base64.encode(jsonString.codeUnits);
    return encoded;
  }

  /// Validate if the chart is valid
  bool isValid() {
    // return options != null &&
    //     (options!.hAxis?.values.isNotEmpty ?? false) &&
    //     (options!.vAxis?.values.isNotEmpty ?? false) &&
    return dataTable.isNotEmpty &&
        dataTable.length >= 2 &&
        dataTable[0].isNotEmpty &&
        dataTable[1].isNotEmpty &&
        dataTable[0].length >= 2 &&
        dataTable[1].length >= 2;
  }
}
