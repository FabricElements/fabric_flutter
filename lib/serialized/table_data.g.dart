// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TableData _$TableDataFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    disallowNullValues: const ['rows'],
  );
  return TableData(
    header: (json['header'] as List<dynamic>?)
        ?.map((e) => TableColumnData.fromJson(e as Map<String, dynamic>?))
        .toList(),
    rows: (json['rows'] as List<dynamic>?)
            ?.map((e) => TableRowData.fromJson(e as Map<String, dynamic>?))
            .toList() ??
        const [],
    footer: json['footer'] as List<dynamic>?,
    active: json['active'] as bool? ?? false,
    level: json['level'] as int? ?? 0,
  );
}

Map<String, dynamic> _$TableDataToJson(TableData instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('header', instance.header?.map((e) => e.toJson()).toList());
  val['rows'] = instance.rows.map((e) => e.toJson()).toList();
  writeNotNull('footer', instance.footer);
  val['active'] = instance.active;
  val['level'] = instance.level;
  return val;
}

TableColumnData _$TableColumnDataFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    disallowNullValues: const ['value', 'label'],
  );
  return TableColumnData(
    value: json['value'] as String? ?? '',
    type: $enumDecodeNullable(_$TableDataTypeEnumMap, json['type']) ??
        TableDataType.string,
    width: (json['width'] as num?)?.toDouble(),
    label: json['label'] as String?,
  );
}

Map<String, dynamic> _$TableColumnDataToJson(TableColumnData instance) {
  final val = <String, dynamic>{
    'value': instance.value,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('label', instance.label);
  val['type'] = _$TableDataTypeEnumMap[instance.type];
  val['width'] = instance.width;
  return val;
}

const _$TableDataTypeEnumMap = {
  TableDataType.string: 'string',
  TableDataType.number: 'number',
  TableDataType.date: 'date',
  TableDataType.currency: 'currency',
  TableDataType.path: 'path',
  TableDataType.link: 'link',
};

TableRowData _$TableRowDataFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    disallowNullValues: const ['cells', 'child'],
  );
  return TableRowData(
    cells: json['cells'] as List<dynamic>? ?? [],
    child: json['child'] == null
        ? null
        : TableData.fromJson(json['child'] as Map<String, dynamic>?),
    active: json['active'] as bool? ?? false,
  );
}

Map<String, dynamic> _$TableRowDataToJson(TableRowData instance) {
  final val = <String, dynamic>{
    'cells': instance.cells,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('child', instance.child?.toJson());
  val['active'] = instance.active;
  return val;
}
