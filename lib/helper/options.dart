import 'package:flutter/widgets.dart';

/// Predefined options for internal components

/// ButtonOptions
class ButtonOptions {
  /// icon
  IconData? icon;

  /// Trailing Icon
  IconData? trailingIcon;

  /// Define id
  String? id;

  /// Define label text for the button
  String label;

  /// Define labelAlt alt text for the button
  String? labelAlt;

  /// onTap button
  Function? onTap;

  /// path to redirect
  String? path;

  /// QueryParameters to use with path
  Map<String, List<String>>? queryParameters;

  /// set pop to `true` to use Navigator.popAndPushNamed
  bool pop;

  /// set important to `true` to use custom design or functionality
  bool important;

  /// set selected to `true` to use custom design or functionality
  /// Don't use as final in case you need to update it's value programmatically
  bool selected;

  /// set value as dynamic and cast `value as String` or any type required
  dynamic value;

  /// Set children[] for submenus
  List<ButtonOptions> children;

  /// Set image for custom buttons
  String? image;

  /// Set leading widget for custom buttons
  Widget? leading;

  /// Set trailing widget for custom buttons
  Widget? trailing;

  /// Trailing Image
  String? trailingImage;

  ButtonOptions({
    this.children = const [],
    this.icon,
    this.id,
    this.image,
    this.important = false,
    this.label = '',
    this.labelAlt,
    this.onTap,
    this.path,
    this.pop = false,
    this.queryParameters,
    this.selected = false,
    this.value,
    this.leading,
    this.trailing,
    this.trailingIcon,
    this.trailingImage,
  });
}
