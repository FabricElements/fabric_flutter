// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_command_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentCommandInfo _$AgentCommandInfoFromJson(Map<String, dynamic> json) =>
    AgentCommandInfo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'general',
      params:
          (json['params'] as List<dynamic>?)
              ?.map((e) => AgentParam.fromJson(e as Map<String, dynamic>?))
              .toList() ??
          const [],
      requiresRole: json['requiresRole'] as String?,
    );

Map<String, dynamic> _$AgentCommandInfoToJson(AgentCommandInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'params': instance.params.map((e) => e.toJson()).toList(),
      'requiresRole': instance.requiresRole,
    };
