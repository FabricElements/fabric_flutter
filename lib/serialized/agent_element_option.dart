import 'package:json_annotation/json_annotation.dart';

part 'agent_element_option.g.dart';

/// Represents one possible value for a choice input such as a dropdown, enum
/// list, or radio group.
///
/// Each option pairs a JSON-safe [value] with a human-readable [label]. The
/// [value] is what `set_value` accepts; the [label] is what the user sees in
/// the UI.
@JsonSerializable(explicitToJson: true)
class AgentElementOption {
  /// Creates an option with a [value] and an optional [label].
  AgentElementOption({required this.value, this.label});

  /// Builds an [AgentElementOption] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map.
  factory AgentElementOption.fromJson(Map<String, dynamic>? json) =>
      _$AgentElementOptionFromJson(json ?? {});

  /// The JSON-safe value that `set_value` accepts to select this option.
  ///
  /// This is normalized the same way as [AgentElementSnapshot.value]: a
  /// string, number, boolean, or `null`.
  final Object? value;

  /// The human-readable label shown to the user, localized when the widget
  /// renders in a locale-aware context.
  final String? label;

  /// Converts this option into JSON.
  Map<String, dynamic> toJson() => _$AgentElementOptionToJson(this);
}
