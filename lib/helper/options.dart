import 'dart:ui';

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
  final VoidCallback? onTap;

  /// [path] to redirect
  final String? path;

  /// set [pop] to `true` to use Navigator.popAndPushNamed
  final bool pop;

  /// set [important] to `true` to use custom design or functionality
  final bool important;

  /// set [selected] to `true` to use custom design or functionality
  bool selected;

  ButtonOptions({
    this.icon,
    this.id,
    this.important = false,
    required this.label,
    this.labelAlt,
    this.onTap,
    this.path,
    this.pop = false,
    this.selected = false,
  });
}
