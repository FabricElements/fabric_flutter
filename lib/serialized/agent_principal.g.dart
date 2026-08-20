// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_principal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentPrincipal _$AgentPrincipalFromJson(Map<String, dynamic> json) =>
    AgentPrincipal(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      groups:
          (json['groups'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      scopes:
          (json['scopes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      claims: json['claims'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AgentPrincipalToJson(AgentPrincipal instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': instance.role,
      'groups': instance.groups,
      'scopes': instance.scopes,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'claims': instance.claims,
    };
