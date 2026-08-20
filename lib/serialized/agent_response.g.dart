// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentResponse _$AgentResponseFromJson(Map<String, dynamic> json) =>
    AgentResponse(
      id: json['id'] as String? ?? '',
      ok: json['ok'] as bool? ?? false,
      result: json['result'],
      error: json['error'] == null
          ? null
          : AgentError.fromJson(json['error'] as Map<String, dynamic>?),
    );

Map<String, dynamic> _$AgentResponseToJson(AgentResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ok': instance.ok,
      'result': instance.result,
      'error': instance.error?.toJson(),
    };
