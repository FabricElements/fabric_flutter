import 'dart:async';

import 'package:flutter/material.dart';

import '../../serialized/agent_element_snapshot.dart';

/// Reads a live value from the widget that owns an [AgentElementHandle].
typedef AgentValueGetter = Object? Function();

/// Reports a live boolean state, such as whether an element is enabled.
typedef AgentStateGetter = bool Function();

/// Applies a new value to the widget that owns an [AgentElementHandle].
///
/// Implementations must behave exactly as user input would, including
/// validation and listener notification.
typedef AgentValueSetter = FutureOr<void> Function(Object? value);

/// Activates the widget that owns an [AgentElementHandle], as a tap would.
typedef AgentActivator = FutureOr<void> Function();

/// Represents one indexed widget an agent can read from or act on.
///
/// Handles are created by `AgentElement` when a widget declares an
/// `automationKey`, and they are removed again when that widget is disposed.
/// Every observable field is read through a callback so a snapshot always
/// reflects the widget's current state instead of a cached copy.
class AgentElementHandle {
  /// Creates a handle for the element identified by [id].
  AgentElementHandle({
    required this.id,
    this.type = AgentElementType.other,
    this.label,
    this.hint,
    this.valueGetter,
    this.enabledGetter,
    this.visibleGetter,
    this.setter,
    this.activator,
  });

  /// Identifies the element, mirroring the widget's `automationKey`.
  final String id;

  /// Classifies how an agent can interact with the element.
  AgentElementType type;

  /// Describes the element, mirroring the widget's `semanticsLabel`.
  String? label;

  /// Provides extra guidance, mirroring the widget's `semanticHint`.
  String? hint;

  /// Reads the element's current value; `null` when it carries no value.
  AgentValueGetter? valueGetter;

  /// Reports whether the element currently accepts interaction.
  AgentStateGetter? enabledGetter;

  /// Reports whether the element is currently rendered.
  AgentStateGetter? visibleGetter;

  /// Applies a new value to the element; `null` when it is not settable.
  AgentValueSetter? setter;

  /// Activates the element; `null` when it cannot be tapped.
  AgentActivator? activator;

  /// Reports whether `set_value` can act on this element.
  bool get canSetValue => setter != null;

  /// Reports whether `tap` can act on this element.
  bool get canActivate => activator != null;

  /// Returns the element's current value normalized to a JSON-safe primitive.
  Object? get value => normalizeValue(valueGetter?.call());

  /// Returns whether the element currently accepts interaction.
  bool get enabled => enabledGetter?.call() ?? true;

  /// Returns whether the element is currently rendered.
  bool get visible => visibleGetter?.call() ?? true;

  /// Copies the mutable description fields from [other].
  ///
  /// `AgentElement` calls this when its owning widget rebuilds so the indexed
  /// entry stays current without being unregistered and registered again.
  void updateFrom(AgentElementHandle other) {
    type = other.type;
    label = other.label;
    hint = other.hint;
    valueGetter = other.valueGetter;
    enabledGetter = other.enabledGetter;
    visibleGetter = other.visibleGetter;
    setter = other.setter;
    activator = other.activator;
  }

  /// Returns the element's observable state as a serializable snapshot.
  AgentElementSnapshot snapshot() => AgentElementSnapshot(
    id: id,
    type: type,
    label: label,
    hint: hint,
    value: value,
    enabled: enabled,
    visible: visible,
  );

  /// Converts [value] into a JSON-safe primitive.
  ///
  /// Values that already serialize cleanly are returned unchanged. [DateTime]
  /// becomes an ISO-8601 string, [TimeOfDay] becomes a zero-padded `HH:mm`
  /// string, and an [Enum] becomes its name. Anything else falls back to
  /// `toString` so a transport never has to encode an arbitrary object.
  static Object? normalizeValue(Object? value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is TimeOfDay) {
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (value is Enum) return value.name;
    if (value is Iterable) {
      return value.map(normalizeValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), normalizeValue(item)),
      );
    }
    return value.toString();
  }
}
