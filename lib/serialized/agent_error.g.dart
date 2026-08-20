// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentError _$AgentErrorFromJson(Map<String, dynamic> json) => AgentError(
  code:
      $enumDecodeNullable(_$AgentErrorCodeEnumMap, json['code']) ??
      AgentErrorCode.failed,
  message: json['message'] as String? ?? '',
);

Map<String, dynamic> _$AgentErrorToJson(AgentError instance) =>
    <String, dynamic>{
      'code': _$AgentErrorCodeEnumMap[instance.code]!,
      'message': instance.message,
    };

const _$AgentErrorCodeEnumMap = {
  AgentErrorCode.unauthorized: 'unauthorized',
  AgentErrorCode.notFound: 'not_found',
  AgentErrorCode.invalidParams: 'invalid_params',
  AgentErrorCode.disabled: 'disabled',
  AgentErrorCode.failed: 'failed',
};
