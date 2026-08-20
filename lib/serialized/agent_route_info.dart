import 'package:json_annotation/json_annotation.dart';

part 'agent_route_info.g.dart';

/// Describes a navigable route advertised in `describe` output.
///
/// Hosts publish their route table through this model so an agent can discover
/// every destination it is allowed to reach without scraping the widget tree.
@JsonSerializable(explicitToJson: true)
class AgentRouteInfo {
  /// Creates a serializable description of an application route.
  AgentRouteInfo({
    required this.name,
    this.title,
    this.description,
    this.requiresRole,
  });

  /// Builds an [AgentRouteInfo] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so partial route tables remain
  /// safe to deserialize.
  factory AgentRouteInfo.fromJson(Map<String, dynamic>? json) =>
      _$AgentRouteInfoFromJson(json ?? {});

  /// Stores the named route path, such as `/dashboard`.
  @JsonKey(defaultValue: '')
  final String name;

  /// Provides a short human-readable name for the destination.
  final String? title;

  /// Explains what the route contains and why an agent would visit it.
  final String? description;

  /// Names the role required to reach the route, when access is restricted.
  ///
  /// This layer only carries the metadata; enforcement happens elsewhere.
  final String? requiresRole;

  /// Converts this route description into JSON.
  Map<String, dynamic> toJson() => _$AgentRouteInfoToJson(this);
}
