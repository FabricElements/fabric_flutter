import 'package:json_annotation/json_annotation.dart';

part 'agent_request.g.dart';

/// Represents a decoded JSON-RPC-shaped request sent to the agent bridge.
///
/// The bridge is transport agnostic: any layer that can produce this shape —
/// a socket frame, a JavaScript interop call, or a direct in-process call — can
/// drive the application without changing the protocol.
@JsonSerializable(explicitToJson: true)
class AgentRequest {
  /// Creates a request addressed to a bridge method.
  AgentRequest({required this.id, required this.method, this.params});

  /// Builds an [AgentRequest] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so malformed frames produce an
  /// empty request rather than throwing at the transport boundary.
  factory AgentRequest.fromJson(Map<String, dynamic>? json) =>
      _$AgentRequestFromJson(json ?? {});

  /// Correlates the request with its response.
  @JsonKey(defaultValue: '')
  final String id;

  /// Names the bridge method to run, such as `describe`, `state`, or `invoke`.
  @JsonKey(defaultValue: '')
  final String method;

  /// Carries the method arguments; `null` when the method takes none.
  final Map<String, dynamic>? params;

  /// Converts this request into JSON.
  Map<String, dynamic> toJson() => _$AgentRequestToJson(this);
}
