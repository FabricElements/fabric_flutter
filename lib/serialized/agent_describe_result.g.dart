// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_describe_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentDescribeResult _$AgentDescribeResultFromJson(Map<String, dynamic> json) =>
    AgentDescribeResult(
      app: json['app'] as String? ?? '',
      version: json['version'] as String? ?? '',
      routes:
          (json['routes'] as List<dynamic>?)
              ?.map((e) => AgentRouteInfo.fromJson(e as Map<String, dynamic>?))
              .toList() ??
          const [],
      commands:
          (json['commands'] as List<dynamic>?)
              ?.map(
                (e) => AgentCommandInfo.fromJson(e as Map<String, dynamic>?),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AgentDescribeResultToJson(
  AgentDescribeResult instance,
) => <String, dynamic>{
  'app': instance.app,
  'version': instance.version,
  'routes': instance.routes.map((e) => e.toJson()).toList(),
  'commands': instance.commands.map((e) => e.toJson()).toList(),
};
