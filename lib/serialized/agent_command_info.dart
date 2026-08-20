import 'package:json_annotation/json_annotation.dart';

import 'agent_param.dart';

part 'agent_command_info.g.dart';

/// Describes a single agent command exactly as it appears in `describe` output.
///
/// This model is deliberately data-only: the executable handler lives beside it
/// in `AgentCommand` (`lib/helper/agent/agent_command.dart`) so the catalog can
/// be serialized and shipped over any transport.
@JsonSerializable(explicitToJson: true)
class AgentCommandInfo {
  /// Creates a serializable description of an agent command.
  AgentCommandInfo({
    required this.id,
    required this.title,
    this.description,
    this.category = 'general',
    this.params = const [],
    this.requiresRole,
  });

  /// Builds an [AgentCommandInfo] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so partial catalogs remain
  /// safe to deserialize.
  factory AgentCommandInfo.fromJson(Map<String, dynamic>? json) =>
      _$AgentCommandInfoFromJson(json ?? {});

  /// Uniquely identifies the command inside an `AgentRegistry`.
  @JsonKey(defaultValue: '')
  final String id;

  /// Provides a short human-readable name for the command.
  @JsonKey(defaultValue: '')
  final String title;

  /// Explains what the command does and when an agent should use it.
  final String? description;

  /// Groups related commands so agents can browse the catalog by area.
  @JsonKey(defaultValue: 'general')
  final String category;

  /// Lists the parameters accepted by the command; empty when it takes none.
  final List<AgentParam> params;

  /// Names the role required to invoke the command, when access is restricted.
  ///
  /// This layer only carries the metadata. Enforcement is performed by the
  /// injected authorizer, which is supplied by a higher layer.
  final String? requiresRole;

  /// Converts this command description into JSON.
  Map<String, dynamic> toJson() => _$AgentCommandInfoToJson(this);
}
