import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import 'smart_image.dart';

/// Displays a horizontal breadcrumb navigation trail.
///
/// [Breadcrumbs] provides a visual navigation path that shows the user's current
/// location within a hierarchical structure. Each breadcrumb is rendered as either
/// a clickable [ActionChip] (if it has navigation or callback) or a static [Chip].
/// Breadcrumbs are separated by forward slashes and scroll horizontally if the
/// content exceeds available width.
///
/// The component integrates with [AppLocalizations] for internationalized labels
/// and supports both programmatic navigation (via [ButtonOptions.path]) and
/// custom actions (via [ButtonOptions.onTap]).
class Breadcrumbs extends StatelessWidget {
  /// Creates a breadcrumb navigation component.
  ///
  /// The [buttons] parameter is required and defines the breadcrumb items to display.
  const Breadcrumbs({
    super.key,
    required this.buttons,
    this.buttonStyle,
    this.dividerStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
    this.textStyle,
  });

  /// The list of button configurations that make up the breadcrumb trail.
  ///
  /// Each button represents one level in the navigation hierarchy, ordered from
  /// root to current location. Buttons can include icons, images, or just text.
  final List<ButtonOptions> buttons;

  /// Custom button styling applied to all clickable breadcrumb chips.
  ///
  /// If null, the default ActionChip styling is used with transparent backgrounds.
  final ButtonStyle? buttonStyle;

  /// Text style for the divider characters (forward slashes) between breadcrumbs.
  ///
  /// Defaults to bodySmall with the theme's divider color if not provided.
  final TextStyle? dividerStyle;

  /// Padding around the entire breadcrumb container.
  ///
  /// Defaults to 16px horizontal padding to provide comfortable edge spacing.
  final EdgeInsetsGeometry padding;

  /// Horizontal spacing between breadcrumb items and dividers.
  ///
  /// Defaults to 8px for balanced visual separation.
  final double spacing;

  /// Text style applied to breadcrumb labels.
  ///
  /// Defaults to the theme's bodySmall text style if not provided.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    List<Widget> items = [];
    TextStyle? textStyleDefault = textStyle ?? textTheme.bodySmall;
    TextStyle? dividerStyleDefault = dividerStyle ??
        textTheme.bodySmall?.copyWith(color: theme.dividerTheme.color);
    for (int i = 0; i < buttons.length; i++) {
      ButtonOptions button = buttons[i];
      String label = locales.get(button.label);
      bool clickable = button.path != null || button.onTap != null;
      VoidCallback? onPressed;
      if (clickable) {
        onPressed = () {
          if (button.onTap != null) button.onTap!();
          if (button.path != null) {
            Navigator.of(context).popAndPushNamed(button.path!);
          }
        };
      }
      Widget? iconButton;
      if (button.icon != null) {
        iconButton = Icon(button.icon);
      }
      if (button.image != null) {
        iconButton = CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          child: ClipOval(
            child: SmartImage(
              url: button.image,
              format: AvailableOutputFormats.png,
            ),
          ),
        );
      }
      if (onPressed != null) {
        items.add(
          ActionChip(
            avatar: iconButton,
            onPressed: onPressed,
            label: Text(label, style: textStyleDefault),
            // Force transparent background
            color: WidgetStateProperty.resolveWith<Color?>(
              (states) => Colors.transparent,
            ),
            elevation: 0,
            pressElevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            side: BorderSide.none,
            backgroundColor: Colors.transparent,
          ),
        );
      } else {
        items.add(
          Chip(
            avatar: iconButton,
            label: Text(label, style: textStyleDefault),
            // Force transparent background
            color: WidgetStateProperty.resolveWith<Color?>(
              (states) => Colors.transparent,
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            side: BorderSide.none,
            backgroundColor: Colors.transparent,
          ),
        );
      }
      if (i < (buttons.length - 1)) {
        items.add(Text('/', style: dividerStyleDefault));
      }
    }
    return SingleChildScrollView(
      padding: padding,
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        alignment: WrapAlignment.start,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }
}
