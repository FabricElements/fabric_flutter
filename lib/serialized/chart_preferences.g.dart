// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChartPreferences _$ChartPreferencesFromJson(Map<String, dynamic> json) =>
    ChartPreferences(
      name: json['name'] as String?,
      hAxis: json['hAxis'] as String?,
      vAxis: json['vAxis'] as String?,
      series1: json['series1'] as String?,
      series2: json['series2'] as String?,
      series3: json['series3'] as String?,
      type:
          $enumDecodeNullable(_$ChartTypeEnumMap, json['type']) ??
          ChartType.Histogram,
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ChartPreferencesToJson(ChartPreferences instance) =>
    <String, dynamic>{
      'name': instance.name,
      'hAxis': instance.hAxis,
      'vAxis': instance.vAxis,
      'series1': instance.series1,
      'series2': instance.series2,
      'series3': instance.series3,
      'type': _$ChartTypeEnumMap[instance.type]!,
      'min': instance.min,
      'max': instance.max,
    };

const _$ChartTypeEnumMap = {
  ChartType.AreaChart: 'AreaChart',
  ChartType.BarChart: 'BarChart',
  ChartType.BubbleChart: 'BubbleChart',
  ChartType.Calendar: 'Calendar',
  ChartType.ColumnChart: 'ColumnChart',
  ChartType.ComboChart: 'ComboChart',
  ChartType.Gauge: 'Gauge',
  ChartType.GeoChart: 'GeoChart',
  ChartType.LineChart: 'LineChart',
  ChartType.PieChart: 'PieChart',
  ChartType.ScatterChart: 'ScatterChart',
  ChartType.SteppedAreaChart: 'SteppedAreaChart',
  ChartType.Table: 'Table',
  ChartType.TreeMap: 'TreeMap',
  ChartType.AnnotationChart: 'AnnotationChart',
  ChartType.CandlestickChart: 'CandlestickChart',
  ChartType.Gantt: 'Gantt',
  ChartType.Histogram: 'Histogram',
  ChartType.OrgChart: 'OrgChart',
  ChartType.Sankey: 'Sankey',
  ChartType.Timeline: 'Timeline',
  ChartType.WordTree: 'WordTree',
};
