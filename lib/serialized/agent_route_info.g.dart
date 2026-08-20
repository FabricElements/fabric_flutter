// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_route_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentRouteInfo _$AgentRouteInfoFromJson(Map<String, dynamic> json) =>
    AgentRouteInfo(
      name: json['name'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      requiresRole: json['requiresRole'] as String?,
    );

Map<String, dynamic> _$AgentRouteInfoToJson(AgentRouteInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'title': instance.title,
      'description': instance.description,
      'requiresRole': instance.requiresRole,
    };
