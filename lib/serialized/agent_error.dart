import 'package:json_annotation/json_annotation.dart';

part 'agent_error.g.dart';

/// Enumerates every failure category the agent bridge can report.
///
/// The taxonomy is closed on purpose: an agent can branch on the code without
/// parsing the human-readable message.
enum AgentErrorCode {
  /// Reports that the caller is not allowed to run the requested command.
  @JsonValue('unauthorized')
  unauthorized,

  /// Reports that the requested command, element, or route does not exist.
  @JsonValue('not_found')
  notFound,

  /// Reports that the supplied parameters are missing or malformed.
  @JsonValue('invalid_params')
  invalidParams,

  /// Reports that the bridge is turned off and is serving no requests.
  @JsonValue('disabled')
  disabled,

  /// Reports that the command ran but threw, or exceeded its timeout.
  @JsonValue('failed')
  failed,
}

/// Describes why an agent request could not be fulfilled.
@JsonSerializable(explicitToJson: true)
class AgentError {
  /// Creates an error payload for a failed agent request.
  AgentError({required this.code, required this.message});

  /// Builds an [AgentError] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map and yields a generic
  /// [AgentErrorCode.failed] error rather than throwing.
  factory AgentError.fromJson(Map<String, dynamic>? json) =>
      _$AgentErrorFromJson(json ?? {});

  /// Classifies the failure so agents can branch without parsing text.
  @JsonKey(defaultValue: AgentErrorCode.failed)
  final AgentErrorCode code;

  /// Explains the failure in human-readable form.
  @JsonKey(defaultValue: '')
  final String message;

  /// Converts this error into JSON.
  Map<String, dynamic> toJson() => _$AgentErrorToJson(this);
}
