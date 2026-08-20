// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentRequest _$AgentRequestFromJson(Map<String, dynamic> json) => AgentRequest(
  id: json['id'] as String? ?? '',
  method: json['method'] as String? ?? '',
  params: json['params'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$AgentRequestToJson(AgentRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'method': instance.method,
      'params': instance.params,
    };
