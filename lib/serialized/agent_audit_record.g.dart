// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_audit_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentAuditRecord _$AgentAuditRecordFromJson(Map<String, dynamic> json) =>
    AgentAuditRecord(
      timestamp: _timestampFromJson(json['timestamp']),
      requestId: json['requestId'] as String? ?? '',
      principalId: json['principalId'] as String? ?? '',
      commandId: json['commandId'] as String? ?? '',
      outcome:
          $enumDecodeNullable(_$AgentAuditOutcomeEnumMap, json['outcome']) ??
          AgentAuditOutcome.failure,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      params:
          (json['params'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      errorCode: $enumDecodeNullable(
        _$AgentErrorCodeEnumMap,
        json['errorCode'],
      ),
      transport: json['transport'] as String? ?? '',
    );

Map<String, dynamic> _$AgentAuditRecordToJson(AgentAuditRecord instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.toIso8601String(),
      'requestId': instance.requestId,
      'principalId': instance.principalId,
      'commandId': instance.commandId,
      'outcome': _$AgentAuditOutcomeEnumMap[instance.outcome]!,
      'durationMs': instance.durationMs,
      'params': instance.params,
      'errorCode': _$AgentErrorCodeEnumMap[instance.errorCode],
      'transport': instance.transport,
    };

const _$AgentAuditOutcomeEnumMap = {
  AgentAuditOutcome.success: 'success',
  AgentAuditOutcome.failure: 'failure',
};

const _$AgentErrorCodeEnumMap = {
  AgentErrorCode.unauthorized: 'unauthorized',
  AgentErrorCode.notFound: 'not_found',
  AgentErrorCode.invalidParams: 'invalid_params',
  AgentErrorCode.disabled: 'disabled',
  AgentErrorCode.failed: 'failed',
};
