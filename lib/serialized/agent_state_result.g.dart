// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_state_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentStateResult _$AgentStateResultFromJson(Map<String, dynamic> json) =>
    AgentStateResult(
      route: json['route'] as String?,
      path: json['path'] as String?,
      params: json['params'] as Map<String, dynamic>? ?? const {},
      elements:
          (json['elements'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AgentElementSnapshot.fromJson(e as Map<String, dynamic>?),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AgentStateResultToJson(AgentStateResult instance) =>
    <String, dynamic>{
      'route': instance.route,
      'path': instance.path,
      'params': instance.params,
      'elements': instance.elements.map((e) => e.toJson()).toList(),
    };
