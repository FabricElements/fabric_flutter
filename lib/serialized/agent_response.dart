import 'package:json_annotation/json_annotation.dart';

import 'agent_error.dart';

part 'agent_response.g.dart';

/// Represents the reply the agent bridge returns for a single request.
///
/// Exactly one of [result] and [error] is meaningful: [result] when [ok] is
/// `true`, and [error] when [ok] is `false`.
@JsonSerializable(explicitToJson: true)
class AgentResponse {
  /// Creates a response correlated with a request [id].
  AgentResponse({required this.id, required this.ok, this.result, this.error});

  /// Creates a successful response carrying [result].
  AgentResponse.success({required this.id, this.result})
    : ok = true,
      error = null;

  /// Creates a failed response carrying [error].
  AgentResponse.failure({required this.id, required AgentError this.error})
    : ok = false,
      result = null;

  /// Builds an [AgentResponse] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so malformed frames produce an
  /// empty response rather than throwing at the transport boundary.
  factory AgentResponse.fromJson(Map<String, dynamic>? json) =>
      _$AgentResponseFromJson(json ?? {});

  /// Correlates the response with the request that produced it.
  @JsonKey(defaultValue: '')
  final String id;

  /// Reports whether the request succeeded.
  @JsonKey(defaultValue: false)
  final bool ok;

  /// Carries the method payload when [ok] is `true`.
  final Object? result;

  /// Describes the failure when [ok] is `false`.
  final AgentError? error;

  /// Converts this response into JSON.
  Map<String, dynamic> toJson() => _$AgentResponseToJson(this);
}
