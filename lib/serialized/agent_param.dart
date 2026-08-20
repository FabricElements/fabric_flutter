import 'package:json_annotation/json_annotation.dart';

part 'agent_param.g.dart';

/// Enumerates the value types an [AgentParam] can accept.
///
/// The wire values intentionally mirror the JSON Schema primitive names used by
/// MCP tool definitions, so an `describe` payload can be forwarded to a remote
/// MCP server without translation.
enum AgentParamType {
  /// Accepts a textual value.
  @JsonValue('string')
  string,

  /// Accepts a numeric value, integral or fractional.
  @JsonValue('number')
  number,

  /// Accepts an integral numeric value.
  @JsonValue('integer')
  integer,

  /// Accepts a `true` or `false` value.
  @JsonValue('boolean')
  boolean,

  /// Accepts a nested JSON object.
  @JsonValue('object')
  object,

  /// Accepts a JSON array of values.
  @JsonValue('array')
  array,
}

/// Describes a single parameter accepted by an agent command.
///
/// The shape maps one-to-one onto an MCP tool input property, so a transport
/// layer can publish the command catalog as MCP tools without reshaping it.
@JsonSerializable(explicitToJson: true)
class AgentParam {
  /// Creates a parameter description for an agent command.
  AgentParam({
    required this.name,
    this.type = AgentParamType.string,
    this.required = false,
    this.enumValues,
    this.description,
  });

  /// Builds an [AgentParam] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so partial catalogs remain
  /// safe to deserialize.
  factory AgentParam.fromJson(Map<String, dynamic>? json) =>
      _$AgentParamFromJson(json ?? {});

  /// Identifies the parameter inside the `params` map of an `invoke` request.
  @JsonKey(defaultValue: '')
  final String name;

  /// Declares the accepted value type.
  @JsonKey(defaultValue: AgentParamType.string)
  final AgentParamType type;

  /// Reports whether the parameter must be present in every request.
  @JsonKey(defaultValue: false)
  final bool required;

  /// Restricts the accepted values to a closed set when non-`null`.
  ///
  /// Serialized as `enum` to match the JSON Schema keyword expected by MCP
  /// clients while keeping the Dart field name legal.
  @JsonKey(name: 'enum')
  final List<String>? enumValues;

  /// Explains the parameter to a human or an autonomous agent.
  final String? description;

  /// Converts this parameter description into JSON.
  Map<String, dynamic> toJson() => _$AgentParamToJson(this);
}
