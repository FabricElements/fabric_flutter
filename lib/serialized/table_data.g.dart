// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TableData _$TableDataFromJson(Map<String, dynamic> json) {
  $checkKeys(json, disallowNullValues: const ['rows']);
  return TableData(
    header:
        (json['header'] as List<dynamic>?)
            ?.map((e) => TableColumnData.fromJson(e as Map<String, dynamic>?))
            .toList(),
    rows:
        (json['rows'] as List<dynamic>?)
            ?.map((e) => TableRowData.fromJson(e as Map<String, dynamic>?))
            .toList() ??
        const [],
    footer: json['footer'] as List<dynamic>?,
    active: json['active'] as bool? ?? false,
    level: (json['level'] as num?)?.toInt() ?? 0,
  );
}

Map<String, dynamic> _$TableDataToJson(TableData instance) => <String, dynamic>{
  if (instance.header?.map((e) => e.toJson()).toList() case final value?)
    'header': value,
  'rows': instance.rows.map((e) => e.toJson()).toList(),
  if (instance.footer case final value?) 'footer': value,
  'active': instance.active,
  'level': instance.level,
};

TableColumnData _$TableColumnDataFromJson(Map<String, dynamic> json) {
  $checkKeys(json, disallowNullValues: const ['value', 'label']);
  return TableColumnData(
    value: json['value'] as String? ?? '',
    type:
        $enumDecodeNullable(_$TableDataTypeEnumMap, json['type']) ??
        TableDataType.string,
    width: (json['width'] as num?)?.toDouble() ?? 50,
    label: json['label'] as String?,
  );
}

Map<String, dynamic> _$TableColumnDataToJson(TableColumnData instance) =>
    <String, dynamic>{
      'value': instance.value,
      if (instance.label case final value?) 'label': value,
      'type': _$TableDataTypeEnumMap[instance.type]!,
      'width': instance.width,
    };

const _$TableDataTypeEnumMap = {
  TableDataType.string: 'string',
  TableDataType.number: 'number',
  TableDataType.decimal: 'decimal',
  TableDataType.date: 'date',
  TableDataType.currency: 'currency',
  TableDataType.path: 'path',
  TableDataType.link: 'link',
};

TableRowData _$TableRowDataFromJson(Map<String, dynamic> json) {
  $checkKeys(json, disallowNullValues: const ['cells']);
  return TableRowData(
    cells: json['cells'] as List<dynamic>? ?? const [],
    child:
        json['child'] == null
            ? null
            : TableData.fromJson(json['child'] as Map<String, dynamic>?),
    active: json['active'] as bool? ?? false,
  );
}

Map<String, dynamic> _$TableRowDataToJson(TableRowData instance) =>
    <String, dynamic>{
      'cells': instance.cells,
      if (instance.child?.toJson() case final value?) 'child': value,
      'active': instance.active,
    };
