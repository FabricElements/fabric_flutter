import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Predefined options for internal components

/// [ButtonOptions]
class ButtonOptions {
  /// [icon]
  final IconData? icon;

  /// Define [label] text for the button
  final String label;

  /// [onTap] button
  final VoidCallback? onTap;

  /// [path] to redirect
  final String? path;

  /// set [pop] to `true` to use Navigator.popAndPushNamed
  final bool? pop;

  ButtonOptions({
    this.icon,
    required this.label,
    this.onTap,
    this.path,
    this.pop,
  });
}
