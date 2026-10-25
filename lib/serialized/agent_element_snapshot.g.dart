// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_element_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentElementSnapshot _$AgentElementSnapshotFromJson(
  Map<String, dynamic> json,
) => AgentElementSnapshot(
  id: json['id'] as String? ?? '',
  type:
      $enumDecodeNullable(_$AgentElementTypeEnumMap, json['type']) ??
      AgentElementType.other,
  label: json['label'] as String?,
  hint: json['hint'] as String?,
  value: json['value'],
  enabled: json['enabled'] as bool? ?? true,
  visible: json['visible'] as bool? ?? true,
  error: json['error'] as String?,
  actions: (json['actions'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  options: (json['options'] as List<dynamic>?)
      ?.map((e) => AgentElementOption.fromJson(e as Map<String, dynamic>?))
      .toList(),
);

Map<String, dynamic> _$AgentElementSnapshotToJson(
  AgentElementSnapshot instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$AgentElementTypeEnumMap[instance.type]!,
  'label': instance.label,
  'hint': instance.hint,
  'value': instance.value,
  'enabled': instance.enabled,
  'visible': instance.visible,
  'error': instance.error,
  'actions': instance.actions,
  'options': instance.options?.map((e) => e.toJson()).toList(),
};

const _$AgentElementTypeEnumMap = {
  AgentElementType.button: 'button',
  AgentElementType.textInput: 'text_input',
  AgentElementType.dropdown: 'dropdown',
  AgentElementType.checkbox: 'checkbox',
  AgentElementType.radio: 'radio',
  AgentElementType.datePicker: 'date_picker',
  AgentElementType.text: 'text',
  AgentElementType.image: 'image',
  AgentElementType.navigation: 'navigation',
  AgentElementType.other: 'other',
};
