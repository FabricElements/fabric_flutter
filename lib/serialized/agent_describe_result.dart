import 'package:json_annotation/json_annotation.dart';

import 'agent_command_info.dart';
import 'agent_route_info.dart';

part 'agent_describe_result.g.dart';

/// Carries the payload returned by the bridge's `describe` method.
///
/// The shape is intentionally MCP-friendly: [commands] maps one-to-one onto MCP
/// tool definitions, so a remote MCP server can wrap the catalog without any
/// protocol change.
@JsonSerializable(explicitToJson: true)
class AgentDescribeResult {
  /// Creates the catalog describing an application to an agent.
  AgentDescribeResult({
    required this.app,
    required this.version,
    this.routes = const [],
    this.commands = const [],
  });

  /// Builds an [AgentDescribeResult] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so partial catalogs remain
  /// safe to deserialize.
  factory AgentDescribeResult.fromJson(Map<String, dynamic>? json) =>
      _$AgentDescribeResultFromJson(json ?? {});

  /// Names the application being driven.
  @JsonKey(defaultValue: '')
  final String app;

  /// Reports the application version string.
  @JsonKey(defaultValue: '')
  final String version;

  /// Lists every route an agent may navigate to; empty when none are published.
  final List<AgentRouteInfo> routes;

  /// Lists every registered command; empty when the registry is empty.
  final List<AgentCommandInfo> commands;

  /// Converts this catalog into JSON.
  Map<String, dynamic> toJson() => _$AgentDescribeResultToJson(this);
}
