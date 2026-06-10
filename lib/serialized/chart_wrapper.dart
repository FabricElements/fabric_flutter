import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'chart_wrapper.g.dart';

// ignore_for_file: constant_identifier_names

/// Enumerates the Google Charts visualizations supported by [ChartWrapper].
///
/// These values are serialized directly and forwarded to the chart renderer so a
/// persisted chart configuration can be recreated without additional mapping.
/// See https://developers.google.com/chart/interactive/docs/gallery.
enum ChartType {
  /// Renders a filled area chart for continuous series data.
  AreaChart,

  /// Renders a horizontal or vertical bar chart.
  BarChart,

  /// Renders a bubble chart with x, y, and size dimensions.
  BubbleChart,

  /// Renders a calendar heatmap grouped by day.
  Calendar,

  /// Renders a column chart with vertical bars.
  ColumnChart,

  /// Renders a combo chart that mixes multiple series styles.
  ComboChart,

  /// Renders a gauge visualization for bounded numeric values.
  Gauge,

  /// Renders a geographic chart using region or coordinate data.
  GeoChart,

  /// Renders a standard line chart for trend visualization.
  LineChart,

  /// Renders a pie chart for part-to-whole comparisons.
  PieChart,

  /// Renders a scatter chart for point distributions.
  ScatterChart,

  /// Renders a stepped area chart for discontinuous changes.
  SteppedAreaChart,

  /// Renders a tabular chart representation.
  Table,

  /// Renders a tree map for hierarchical numeric data.
  TreeMap,

  /// Renders an annotation chart for time-series exploration.
  AnnotationChart,

  /// Renders a candlestick chart for range-based values.
  CandlestickChart,

  /// Renders a Gantt chart for timeline planning data.
  Gantt,

  /// Renders a histogram for frequency distributions.
  Histogram,

  /// Renders an organizational chart.
  OrgChart,

  /// Renders a Sankey diagram for flow relationships.
  Sankey,

  /// Renders a timeline chart for interval-based events.
  Timeline,

  /// Renders a word tree from hierarchical phrases.
  WordTree,

  // WaterfallChart,
}

/// Defines where a chart legend should appear.
///
/// These values mirror the Google Charts legend position options so serialized
/// settings can be passed through without translation.
enum ChartWrapperLegendPosition {
  /// Places the legend below the chart.
  bottom,

  /// Places the legend to the left of the chart.
  left,

  // 'in',

  /// Hides the legend entirely.
  none,

  /// Places the legend to the right of the chart.
  right,

  /// Places the legend above the chart.
  top,
}

/// Defines how legend entries should align within the legend container.
///
/// Alignment is only meaningful for positions where the legend has spare space
/// to arrange its content.
enum ChartWrapperLegendAlignment {
  /// Centers legend content within the available space.
  center,

  /// Aligns legend content to the end edge.
  end,

  /// Aligns legend content to the start edge.
  start,
}

/// Defines the primary drawing direction for supported chart types.
///
/// Orientation only affects chart types that expose horizontal and vertical
/// rendering modes, such as bar-style charts.
enum ChartWrapperOrientation {
  /// Draws the chart left-to-right.
  horizontal,

  /// Draws the chart bottom-to-top.
  vertical,
}

/// Describes legend behavior for a serialized [ChartWrapper].
///
/// Keeping legend settings in a separate object allows callers to persist or
/// reuse chart-specific legend choices independently from other chart options.
@JsonSerializable(explicitToJson: true)
class ChartWrapperLegend {
  /// Controls where the legend is rendered.
  @JsonKey(includeIfNull: false)
  final ChartWrapperLegendPosition? position;

  /// Controls how items align within the legend area.
  @JsonKey(includeIfNull: false)
  final ChartWrapperLegendAlignment? alignment;

  /// Limits the number of legend lines when the renderer supports wrapping.
  @JsonKey(disallowNullValue: false)
  final int? maxLines;

  /// Selects the active legend page for paginated legends.
  @JsonKey(disallowNullValue: false)
  final int? pageIndex;

  /// Applies text styling to legend labels using Google Charts style keys.
  @JsonKey(includeIfNull: false)
  final Map<String, String>? textStyle;

  /// Creates legend metadata for a serialized chart.
  ChartWrapperLegend({
    this.position,
    this.alignment,
    this.maxLines,
    this.pageIndex,
    this.textStyle,
  });

  /// Builds a [ChartWrapperLegend] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty configuration so callers can safely
  /// deserialize partially populated chart settings.
  factory ChartWrapperLegend.fromJson(Map<String, dynamic>? json) =>
      _$ChartWrapperLegendFromJson(json ?? {});

  /// Converts this legend configuration into JSON.
  Map<String, dynamic> toJson() => _$ChartWrapperLegendToJson(this);
}

/// Stores Google Charts configuration for a [ChartWrapper].
///
/// This object contains renderer-specific option maps that are intentionally
/// flexible because Google Charts accepts a broad set of loosely typed values.
@JsonSerializable(explicitToJson: true)
class ChartWrapperOptions {
  /// Provides the chart title shown by supporting chart types.
  @JsonKey(includeIfNull: true)
  final String? title;

  /// Configures the vertical axis using Google Charts axis option keys.
  @JsonKey(includeIfNull: true)
  final Map<String, String>? vAxis;

  /// Configures the horizontal axis using Google Charts axis option keys.
  @JsonKey(includeIfNull: true)
  final Map<String, String>? hAxis;

  /// Chooses the default series renderer for combo charts.
  @JsonKey(includeIfNull: true)
  final String? seriesType;

  /// Overrides rendering options for specific series indexes.
  @JsonKey(includeIfNull: true)
  final Map<int, Map<String, dynamic>>? series;

  /// Configures histogram-specific behavior.
  ///
  /// The default ensures histograms start at zero and visually separate items,
  /// which produces more readable output for most generated datasets.
  final Map<String, dynamic> histogram;

  /// Supplies the color palette used for rendered series.
  final List<String>? colors;

  /// Configures timeline-specific options.
  final Map<String, dynamic>? timeline;

  /// Configures the inner chart drawing area.
  final Map<String, dynamic>? chartArea;

  /// Configures trendlines keyed by series index.
  final Map<int, Map<String, dynamic>>? trendlines;

  /// Creates chart option metadata.
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
    this.trendlines,
  });

  /// Builds [ChartWrapperOptions] from serialized JSON.
  ///
  /// A `null` payload becomes an empty options object so consumers can continue
  /// rendering with defaults when persisted options are missing.
  factory ChartWrapperOptions.fromJson(Map<String, dynamic>? json) =>
      _$ChartWrapperOptionsFromJson(json ?? {});

  /// Converts these chart options into JSON.
  Map<String, dynamic> toJson() => _$ChartWrapperOptionsToJson(this);
}

/// Stores a complete Google Charts [ChartWrapper] payload.
///
/// Instances of this class bundle the chart type, raw tabular data, and related
/// presentation options so chart definitions can be serialized, persisted, and
/// later reconstructed by the UI.
@JsonSerializable(explicitToJson: true)
class ChartWrapper {
  /// Selects which Google Charts renderer should be used.
  ///
  /// Unknown serialized values fall back to [ChartType.ColumnChart] so stale or
  /// user-edited payloads still produce a safe default visualization.
  @JsonKey(
    disallowNullValue: true,
    unknownEnumValue: ChartType.ColumnChart,
    defaultValue: ChartType.ColumnChart,
  )
  final ChartType chartType;

  /// Provides renderer-specific configuration for the chart.
  @JsonKey(disallowNullValue: true)
  final ChartWrapperOptions? options;

  /// Stores the raw rows and columns consumed by Google Charts.
  ///
  /// The first row is treated as the header row during serialization. The list
  /// is sanitized by [toJson] because Google Charts rejects unsupported numeric
  /// values such as `NaN` and infinity.
  @JsonKey(includeIfNull: true)
  final List<List<dynamic>> dataTable;

  /// Supplies optional legend configuration.
  @JsonKey(includeIfNull: false)
  final ChartWrapperLegend? legend;

  /// Reverses the category order when the renderer supports it.
  final bool reverseCategories;

  /// Controls chart orientation for compatible chart types.
  @JsonKey(includeIfNull: false)
  final ChartWrapperOrientation? orientation;

  /// Identifies the DOM container that should host the rendered chart.
  final String containerId;

  /// Creates a serialized chart wrapper.
  ChartWrapper({
    required this.chartType,
    this.options,
    this.dataTable = const [],
    this.containerId = 'chart',
    this.legend,
    this.reverseCategories = false,
    this.orientation,
  });

  /// Builds a [ChartWrapper] from serialized JSON.
  ///
  /// A `null` payload is treated as empty input, allowing callers to deserialize
  /// optional chart data without defensive checks beforehand.
  factory ChartWrapper.fromJson(Map<String, dynamic>? json) =>
      _$ChartWrapperFromJson(json ?? {});

  /// Converts this chart wrapper into a JSON-ready map.
  ///
  /// This method also normalizes header cells, converts non-finite numbers to
  /// `null`, and hides crowded horizontal-axis labels for large datasets. It
  /// throws when [dataTable] is empty because the renderer cannot recover from a
  /// missing header row.
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
    // Chart Types that don't have enough space for hAxis labels
    final chartTypesNoHAxisLabels = {ChartType.Histogram};
    // If more than 15 unique values, hide histogram hAxis labels unless chart type is not in the list
    if (uniqueValues.length > 15 &&
        !chartTypesNoHAxisLabels.contains(chartType)) {
      baseData['options']['hAxis'] ??= {};
      baseData['options']['hAxis']['textPosition'] = 'none';
    }
    return baseData;
  }

  /// Encodes the chart as a base64 JSON payload.
  ///
  /// The encoded representation is intended for compact transport. Only the
  /// first 51 rows are included to avoid producing oversized payloads when a
  /// chart contains large datasets.
  String encode() {
    if (options == null) return '';
    // Convert the ChartWrapper to a Map
    Map<String, dynamic> baseData = toJson();
    // Take only the first 50 rows of dataTable to avoid too large data
    if (dataTable.length > 50) {
      baseData['dataTable'] = dataTable.take(51).toList();
    }
    // Convert the baseData to JSON string
    final jsonString = jsonEncode(baseData);
    // Base 64 encode the JSON string
    final encoded = base64.encode(jsonString.codeUnits);
    return encoded;
  }

  /// Returns whether the current chart has enough structure to render.
  ///
  /// Most chart types require at least one header row and one data row with two
  /// columns, but [ChartType.Histogram] and [ChartType.Table] can operate with a
  /// single logical column.
  bool isValid() {
    // Chart types that do not require at lest 2 columns
    final chartTypesDoNotRequire2x2 = {ChartType.Histogram, ChartType.Table};
    int totalColumns = dataTable.isNotEmpty ? dataTable[0].length : 0;
    return dataTable.isNotEmpty &&
        dataTable.length >= 2 &&
        dataTable[0].isNotEmpty &&
        (chartTypesDoNotRequire2x2.contains(chartType) || (totalColumns >= 2));
  }
}
