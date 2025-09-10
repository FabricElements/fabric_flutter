// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_wrapper.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChartWrapperLegend _$ChartWrapperLegendFromJson(Map<String, dynamic> json) =>
    ChartWrapperLegend(
      position: $enumDecodeNullable(
        _$ChartWrapperLegendPositionEnumMap,
        json['position'],
      ),
      alignment: $enumDecodeNullable(
        _$ChartWrapperLegendAlignmentEnumMap,
        json['alignment'],
      ),
      maxLines: (json['maxLines'] as num?)?.toInt(),
      pageIndex: (json['pageIndex'] as num?)?.toInt(),
      textStyle: (json['textStyle'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$ChartWrapperLegendToJson(ChartWrapperLegend instance) =>
    <String, dynamic>{
      'position': ?_$ChartWrapperLegendPositionEnumMap[instance.position],
      'alignment': ?_$ChartWrapperLegendAlignmentEnumMap[instance.alignment],
      'maxLines': instance.maxLines,
      'pageIndex': instance.pageIndex,
      'textStyle': ?instance.textStyle,
    };

const _$ChartWrapperLegendPositionEnumMap = {
  ChartWrapperLegendPosition.bottom: 'bottom',
  ChartWrapperLegendPosition.left: 'left',
  ChartWrapperLegendPosition.none: 'none',
  ChartWrapperLegendPosition.right: 'right',
  ChartWrapperLegendPosition.top: 'top',
};

const _$ChartWrapperLegendAlignmentEnumMap = {
  ChartWrapperLegendAlignment.center: 'center',
  ChartWrapperLegendAlignment.end: 'end',
  ChartWrapperLegendAlignment.start: 'start',
};

ChartWrapperOptions _$ChartWrapperOptionsFromJson(Map<String, dynamic> json) =>
    ChartWrapperOptions(
      title: json['title'] as String?,
      vAxis: (json['vAxis'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      hAxis: (json['hAxis'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      seriesType: json['seriesType'] as String?,
      series: (json['series'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(int.parse(k), Map<String, String>.from(e as Map)),
      ),
      histogram:
          json['histogram'] as Map<String, dynamic>? ??
          const {'minValue': 0, 'showItemDividers': true},
      colors: (json['colors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ChartWrapperOptionsToJson(
  ChartWrapperOptions instance,
) => <String, dynamic>{
  'title': instance.title,
  'vAxis': instance.vAxis,
  'hAxis': instance.hAxis,
  'seriesType': instance.seriesType,
  'series': instance.series?.map((k, e) => MapEntry(k.toString(), e)),
  'histogram': instance.histogram,
  'colors': instance.colors,
};

ChartWrapper _$ChartWrapperFromJson(Map<String, dynamic> json) {
  $checkKeys(json, disallowNullValues: const ['chartType', 'options']);
  return ChartWrapper(
    chartType: $enumDecode(_$ChartTypeEnumMap, json['chartType']),
    options: json['options'] == null
        ? null
        : ChartWrapperOptions.fromJson(
            json['options'] as Map<String, dynamic>?,
          ),
    dataTable:
        (json['dataTable'] as List<dynamic>?)
            ?.map((e) => e as List<dynamic>)
            .toList() ??
        const [],
    containerId: json['containerId'] as String? ?? 'chart',
    legend: json['legend'] == null
        ? null
        : ChartWrapperLegend.fromJson(json['legend'] as Map<String, dynamic>?),
    reverseCategories: json['reverseCategories'] as bool? ?? false,
    orientation: $enumDecodeNullable(
      _$ChartWrapperOrientationEnumMap,
      json['orientation'],
    ),
  );
}

Map<String, dynamic> _$ChartWrapperToJson(ChartWrapper instance) =>
    <String, dynamic>{
      'chartType': _$ChartTypeEnumMap[instance.chartType]!,
      'options': ?instance.options?.toJson(),
      'dataTable': instance.dataTable,
      'legend': ?instance.legend?.toJson(),
      'reverseCategories': instance.reverseCategories,
      'orientation': ?_$ChartWrapperOrientationEnumMap[instance.orientation],
      'containerId': instance.containerId,
    };

const _$ChartTypeEnumMap = {
  ChartType.Table: 'Table',
  ChartType.PieChart: 'PieChart',
  ChartType.ColumnChart: 'ColumnChart',
  ChartType.Histogram: 'Histogram',
  ChartType.ComboChart: 'ComboChart',
  ChartType.ScatterChart: 'ScatterChart',
  ChartType.Timeline: 'Timeline',
};

const _$ChartWrapperOrientationEnumMap = {
  ChartWrapperOrientation.horizontal: 'horizontal',
  ChartWrapperOrientation.vertical: 'vertical',
};
