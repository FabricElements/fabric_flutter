import 'package:json_annotation/json_annotation.dart';

import 'chart_wrapper.dart';

part 'chart_preferences.g.dart';

/// Stores persisted user preferences for building charts.
///
/// These preferences capture how a user wants tabular data mapped into a chart so
/// reports can be recreated consistently without recalculating the selection UI.
@JsonSerializable(explicitToJson: true)
class ChartPreferences {
  /// Stores a user-facing name for the saved preference set.
  String? name;

  /// Stores the field mapped to the horizontal axis.
  ///
  /// This should reference a column with date or string data so categorical and
  /// timeline charts can render readable axis labels.
  String? hAxis;

  /// Stores the field mapped to the vertical axis.
  ///
  /// This should reference a numeric column because chart aggregations and scales
  /// depend on quantitative values.
  String? vAxis;

  /// Stores the first optional grouping series.
  ///
  /// Not every [ChartType] supports additional grouping, so callers may leave
  /// this `null` for simpler chart configurations.
  String? series1;

  /// Stores the second optional grouping series.
  String? series2;

  /// Stores the third optional grouping series.
  String? series3;

  /// Stores the chart type the user wants to render.
  ChartType type;

  /// Stores the optional lower bound used for filtering or chart scaling.
  double? min;

  /// Stores the optional upper bound used for filtering or chart scaling.
  double? max;

  /// Creates serialized chart preferences.
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

  /// Builds [ChartPreferences] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input so missing saved preferences can
  /// be recreated with constructor defaults.
  factory ChartPreferences.fromJson(Map<String, dynamic>? json) =>
      _$ChartPreferencesFromJson(json ?? {});

  /// Converts these chart preferences into JSON.
  Map<String, dynamic> toJson() => _$ChartPreferencesToJson(this);
}
