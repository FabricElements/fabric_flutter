import 'package:json_annotation/json_annotation.dart';

part 'agent_element_snapshot.g.dart';

/// Enumerates the interaction kinds an indexed element can expose.
///
/// The wire values stay snake_case so the payload reads naturally from other
/// languages and matches the rest of the agent protocol.
enum AgentElementType {
  /// Activates an action when tapped.
  @JsonValue('button')
  button,

  /// Edits a free-form or formatted text value.
  @JsonValue('text_input')
  textInput,

  /// Selects one value from a closed list of options.
  @JsonValue('dropdown')
  dropdown,

  /// Toggles between a `true` and `false` value.
  @JsonValue('checkbox')
  checkbox,

  /// Selects one value from a mutually exclusive group.
  @JsonValue('radio')
  radio,

  /// Selects a date, time, or combined date-and-time value.
  @JsonValue('date_picker')
  datePicker,

  /// Presents read-only content.
  @JsonValue('text')
  text,

  /// Represents an element that does not fit any other category.
  @JsonValue('other')
  other,
}

/// Captures the observable state of a single indexed element.
///
/// Snapshots are produced on demand from the live element index, so the values
/// always reflect the widget's current state rather than a cached copy.
@JsonSerializable(explicitToJson: true)
class AgentElementSnapshot {
  /// Creates a snapshot of an indexed element.
  AgentElementSnapshot({
    required this.id,
    this.type = AgentElementType.other,
    this.label,
    this.hint,
    this.value,
    this.enabled = true,
    this.visible = true,
  });

  /// Builds an [AgentElementSnapshot] from serialized JSON.
  ///
  /// A `null` payload is treated as an empty map so partial screen states
  /// remain safe to deserialize.
  factory AgentElementSnapshot.fromJson(Map<String, dynamic>? json) =>
      _$AgentElementSnapshotFromJson(json ?? {});

  /// Identifies the element, mirroring the widget's `automationKey`.
  @JsonKey(defaultValue: '')
  final String id;

  /// Classifies how an agent can interact with the element.
  @JsonKey(defaultValue: AgentElementType.other)
  final AgentElementType type;

  /// Describes the element, mirroring the widget's `semanticsLabel`.
  final String? label;

  /// Provides extra guidance, mirroring the widget's `semanticHint`.
  final String? hint;

  /// Holds the element's current value, normalized to a JSON-safe primitive.
  final Object? value;

  /// Reports whether the element currently accepts interaction.
  @JsonKey(defaultValue: true)
  final bool enabled;

  /// Reports whether the element is currently mounted and rendered.
  @JsonKey(defaultValue: true)
  final bool visible;

  /// Converts this snapshot into JSON.
  Map<String, dynamic> toJson() => _$AgentElementSnapshotToJson(this);
}
