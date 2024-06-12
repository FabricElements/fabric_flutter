// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilterData _$FilterDataFromJson(Map<String, dynamic> json) => FilterData(
      id: json['id'] as String,
      operator: $enumDecodeNullable(_$FilterOperatorEnumMap, json['operator']),
      value: json['value'],
      type: $enumDecodeNullable(_$InputDataTypeEnumMap, json['type']) ??
          InputDataType.string,
      index: (json['index'] as num?)?.toInt() ?? 0,
      group: json['group'],
    );

Map<String, dynamic> _$FilterDataToJson(FilterData instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'type': _$InputDataTypeEnumMap[instance.type]!,
    'operator': _$FilterOperatorEnumMap[instance.operator],
    'value': instance.value,
    'index': instance.index,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('group', instance.group);
  return val;
}

const _$FilterOperatorEnumMap = {
  FilterOperator.equal: 'equal',
  FilterOperator.notEqual: 'notEqual',
  FilterOperator.contains: 'contains',
  FilterOperator.greaterThan: 'greaterThan',
  FilterOperator.greaterThanOrEqual: 'greaterThanOrEqual',
  FilterOperator.lessThan: 'lessThan',
  FilterOperator.lessThanOrEqual: 'lessThanOrEqual',
  FilterOperator.between: 'between',
  FilterOperator.any: 'any',
  FilterOperator.sort: 'sort',
};

const _$InputDataTypeEnumMap = {
  InputDataType.date: 'date',
  InputDataType.time: 'time',
  InputDataType.dateTime: 'dateTime',
  InputDataType.timestamp: 'timestamp',
  InputDataType.email: 'email',
  InputDataType.int: 'int',
  InputDataType.double: 'double',
  InputDataType.currency: 'currency',
  InputDataType.percent: 'percent',
  InputDataType.text: 'text',
  InputDataType.enums: 'enums',
  InputDataType.dropdown: 'dropdown',
  InputDataType.string: 'string',
  InputDataType.radio: 'radio',
  InputDataType.phone: 'phone',
  InputDataType.secret: 'secret',
  InputDataType.url: 'url',
  InputDataType.bool: 'bool',
};
