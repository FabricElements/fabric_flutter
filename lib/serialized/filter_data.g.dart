// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilterData _$FilterDataFromJson(Map<String, dynamic> json) => FilterData(
      id: json['id'] as String,
      operator: $enumDecodeNullable(_$FilterOperatorEnumMap, json['operator']),
      value: json['value'],
      type: $enumDecode(_$InputDataTypeEnumMap, json['type']),
      index: json['index'] as int? ?? 0,
    );

Map<String, dynamic> _$FilterDataToJson(FilterData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$InputDataTypeEnumMap[instance.type]!,
      'operator': _$FilterOperatorEnumMap[instance.operator],
      'value': instance.value,
      'index': instance.index,
    };

const _$FilterOperatorEnumMap = {
  FilterOperator.equal: 'equal',
  FilterOperator.notEqual: 'notEqual',
  FilterOperator.contains: 'contains',
  FilterOperator.greaterThan: 'greaterThan',
  FilterOperator.lessThan: 'lessThan',
  FilterOperator.between: 'between',
  FilterOperator.any: 'any',
};

const _$InputDataTypeEnumMap = {
  InputDataType.date: 'date',
  InputDataType.email: 'email',
  InputDataType.time: 'time',
  InputDataType.double: 'double',
  InputDataType.int: 'int',
  InputDataType.text: 'text',
  InputDataType.enums: 'enums',
  InputDataType.dropdown: 'dropdown',
  InputDataType.string: 'string',
  InputDataType.radio: 'radio',
  InputDataType.phone: 'phone',
  InputDataType.secret: 'secret',
  InputDataType.url: 'url',
};
