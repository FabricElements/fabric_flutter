import 'package:flutter/widgets.dart';

/// Predefined options for internal components.

/// Configures a button with navigation, callback, and visual properties.
///
/// [ButtonOptions] provides a flexible way to define button behavior and appearance
/// across various components like breadcrumbs, tabs, and navigation menus. It supports
/// both navigation-based actions (via [path]) and callback-based actions (via [onTap]),
/// as well as hierarchical menu structures through [children].
class ButtonOptions {
  /// The leading icon to display before the label.
  IconData? icon;

  /// The trailing icon to display after the label or at the end of the button.
  IconData? trailingIcon;

  /// Unique identifier for the button, useful for tracking or distinguishing between buttons.
  String? id;

  /// The primary text label displayed on the button.
  String label;

  /// Alternative label text, can be used for accessibility or context-specific display.
  String? labelAlt;

  /// Callback function executed when the button is tapped.
  ///
  /// If both [onTap] and [path] are provided, [onTap] is executed before navigation.
  Function? onTap;

  /// Navigation path to redirect to when the button is tapped.
  ///
  /// Uses Flutter's named routing system. Can be combined with [queryParameters]
  /// to pass additional data in the URL.
  String? path;

  /// Query parameters to append to the [path] during navigation.
  ///
  /// Useful for passing state or filters through the URL structure.
  Map<String, List<String>>? queryParameters;

  /// When true, uses `Navigator.popAndPushNamed` instead of `Navigator.pushNamed`.
  ///
  /// This replaces the current route instead of stacking it, useful for redirect scenarios.
  bool pop;

  /// When true, indicates this button should be styled or treated as important or primary.
  ///
  /// Components may apply special styling like elevated appearance or accent colors.
  bool important;

  /// When true, indicates this button is currently selected or active.
  ///
  /// Should not be marked as final if you need to programmatically update selection state.
  bool selected;

  /// Dynamic value associated with the button.
  ///
  /// Can be cast to any type required by the consuming component, useful for
  /// passing structured data through button interactions.
  dynamic value;

  /// Child options for creating hierarchical or nested menu structures.
  ///
  /// When populated, this button can act as a submenu trigger.
  List<ButtonOptions> children;

  /// URL of an image to display as a leading element.
  ///
  /// Takes precedence over [icon] if both are provided.
  String? image;

  /// Custom widget to display as a leading element.
  ///
  /// Takes precedence over both [image] and [icon] if provided.
  Widget? leading;

  /// Custom widget to display as a trailing element.
  ///
  /// Takes precedence over [trailingIcon] and [trailingImage] if provided.
  Widget? trailing;

  /// URL of an image to display as a trailing element.
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
