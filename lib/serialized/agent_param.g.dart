// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_param.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentParam _$AgentParamFromJson(Map<String, dynamic> json) => AgentParam(
  name: json['name'] as String? ?? '',
  type:
      $enumDecodeNullable(_$AgentParamTypeEnumMap, json['type']) ??
      AgentParamType.string,
  required: json['required'] as bool? ?? false,
  enumValues: (json['enum'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  description: json['description'] as String?,
);

Map<String, dynamic> _$AgentParamToJson(AgentParam instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': _$AgentParamTypeEnumMap[instance.type]!,
      'required': instance.required,
      'enum': instance.enumValues,
      'description': instance.description,
    };

const _$AgentParamTypeEnumMap = {
  AgentParamType.string: 'string',
  AgentParamType.number: 'number',
  AgentParamType.integer: 'integer',
  AgentParamType.boolean: 'boolean',
  AgentParamType.object: 'object',
  AgentParamType.array: 'array',
};
