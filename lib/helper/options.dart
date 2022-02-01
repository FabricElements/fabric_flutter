import 'package:flutter/widgets.dart';

/// Predefined options for internal components

/// [ButtonOptions]
class ButtonOptions {
  /// [icon]
  final IconData? icon;

  /// Define [id]
  final String? id;

  /// Define [label] text for the button
  final String label;

  /// Define [labelAlt] alt text for the button
  final String? labelAlt;

  /// [onTap] button
  final Function? onTap;

  /// [path] to redirect
  final String? path;

  /// set [pop] to `true` to use Navigator.popAndPushNamed
  final bool pop;

  /// set [important] to `true` to use custom design or functionality
  final bool important;

  /// set [selected] to `true` to use custom design or functionality
  /// Don't use as final in case you need to update it's value programmatically
  bool selected;

  /// set [value] as dynamic and cast `value as String` or any type required
  final dynamic value;

  /// Set [children] for submenus
  final List<ButtonOptions> children;

  ButtonOptions({
    this.children = const [],
    this.icon,
    this.id,
    this.important = false,
    required this.label,
    this.labelAlt,
    this.onTap,
    this.path,
    this.pop = false,
    this.selected = false,
    this.value,
  });
}
