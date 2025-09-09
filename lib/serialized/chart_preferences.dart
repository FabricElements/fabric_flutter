import 'package:json_annotation/json_annotation.dart';

import 'chart_wrapper.dart';

part 'chart_preferences.g.dart';

/// Chart Preferences serialized data
/// Used to store user chart preferences
@JsonSerializable(explicitToJson: true)
class ChartPreferences {
  String? name;

  /// Horizontal Axis: Use columns with date or string data
  String? hAxis;

  /// Vertical Axis: Use columns with numeric data only
  String? vAxis;

  /// Optional series 1 to group by. Not available for all chart types
  String? series1;

  /// Optional series 2 to group by. Not available for all chart types
  String? series2;

  /// Optional series 3 to group by. Not available for all chart types
  String? series3;

  /// Chart type to render
  ChartType type;

  /// Optional value to set range and filtering of the charts using the y axis
  double? min;

  /// Optional value to set range and filtering of the charts using the y axis
  double? max;

  ChartPreferences({
    this.name,
    this.hAxis,
    this.vAxis,
    this.series1,
    this.series2,
    this.series3,
    this.type = ChartType.Histogram,
    this.min,
    this.max,
  });

  factory ChartPreferences.fromJson(Map<String, dynamic>? json) =>
      _$ChartPreferencesFromJson(json ?? {});

  Map<String, dynamic> toJson() => _$ChartPreferencesToJson(this);
}
