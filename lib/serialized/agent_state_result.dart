import 'package:json_annotation/json_annotation.dart';

import 'agent_element_snapshot.dart';

part 'agent_state_result.g.dart';

/// Carries the payload returned by the bridge's `state` and `screen_state`
/// methods.
///
/// It describes where the application currently is and what an agent can read
/// or act on from that screen.
@JsonSerializable(explicitToJson: true)
class AgentStateResult {
  /// Creates a description of the currently visible screen.
  AgentStateResult({
    this.route,
    this.path,
    this.params = const {},
    this.elements = const [],
  });

  /// Builds an [AgentStateResult] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so partial screen states
  /// remain safe to deserialize.
  factory AgentStateResult.fromJson(Map<String, dynamic>? json) =>
      _$AgentStateResultFromJson(json ?? {});

  /// Names the active route, or `null` when it cannot be resolved.
  final String? route;

  /// Stores the active route path; mirrors [route] for named routes.
  final String? path;

  /// Holds the arguments the active route was pushed with; empty when none.
  final Map<String, dynamic> params;

  /// Lists every element currently registered in the live index.
  final List<AgentElementSnapshot> elements;

  /// Converts this screen state into JSON.
  Map<String, dynamic> toJson() => _$AgentStateResultToJson(this);
}
