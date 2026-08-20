import 'package:json_annotation/json_annotation.dart';

import 'agent_error.dart';

part 'agent_audit_record.g.dart';

/// Records one completed agent bridge invocation for auditing.
///
/// A record is written for every `invoke`, whether it succeeded or failed, so a
/// host can answer "which agent did what, when, and did it work" without
/// instrumenting individual commands. Parameters are stored as a **redacted
/// summary** — key names paired with a type description — never as values, so
/// the audit trail can be shipped to a log sink without leaking tokens,
/// secrets, or personal data.
@JsonSerializable(explicitToJson: true)
class AgentAuditRecord {
  /// Creates an audit record for a single invocation.
  AgentAuditRecord({
    required this.timestamp,
    required this.requestId,
    required this.principalId,
    required this.commandId,
    required this.outcome,
    required this.durationMs,
    this.params = const {},
    this.errorCode,
    this.transport = '',
  });

  /// Builds an [AgentAuditRecord] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so a persisted record with
  /// missing fields deserializes rather than throwing.
  factory AgentAuditRecord.fromJson(Map<String, dynamic>? json) =>
      _$AgentAuditRecordFromJson(json ?? {});

  /// Marks when the invocation finished, in UTC.
  ///
  /// A record deserialized without a timestamp falls back to the Unix epoch so
  /// a truncated persisted record still loads.
  @JsonKey(fromJson: _timestampFromJson)
  final DateTime timestamp;

  /// Correlates the record with the originating request.
  @JsonKey(defaultValue: '')
  final String requestId;

  /// Identifies the authenticated caller, or `anonymous` when unauthenticated.
  @JsonKey(defaultValue: '')
  final String principalId;

  /// Names the command that was invoked.
  @JsonKey(defaultValue: '')
  final String commandId;

  /// Reports how the invocation ended.
  @JsonKey(defaultValue: AgentAuditOutcome.failure)
  final AgentAuditOutcome outcome;

  /// Measures how long the invocation took, in milliseconds.
  @JsonKey(defaultValue: 0)
  final int durationMs;

  /// Summarizes the command parameters as key to redacted description.
  ///
  /// Values are never included: a string is summarized as its length, a
  /// collection as its size, and a key whose name looks sensitive as
  /// `<redacted>`.
  final Map<String, String> params;

  /// Classifies the failure when [outcome] is [AgentAuditOutcome.failure].
  final AgentErrorCode? errorCode;

  /// Names the transport that carried the request, such as `websocket`.
  @JsonKey(defaultValue: '')
  final String transport;

  /// Converts this record into JSON.
  Map<String, dynamic> toJson() => _$AgentAuditRecordToJson(this);
}

/// Parses [value] as a timestamp, falling back to the Unix epoch.
///
/// Keeps [AgentAuditRecord.fromJson] null tolerant without making the field
/// nullable for the code that writes records.
DateTime _timestampFromJson(Object? value) {
  if (value is String) return DateTime.parse(value);
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Classifies how an audited invocation ended.
enum AgentAuditOutcome {
  /// Reports that the command ran and returned a result.
  @JsonValue('success')
  success,

  /// Reports that the request was rejected or the command threw.
  @JsonValue('failure')
  failure,
}
