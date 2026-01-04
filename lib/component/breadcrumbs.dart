import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import 'smart_image.dart';

/// Navigation Breadcrumbs provides a useful way to display navigation routes
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({
    super.key,
    required this.buttons,
    this.buttonStyle,
    this.dividerStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
    this.textStyle,
  });

  final List<ButtonOptions> buttons;
  final ButtonStyle? buttonStyle;
  final TextStyle? dividerStyle;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    List<Widget> items = [];
    TextStyle? textStyleDefault = textStyle ?? textTheme.bodySmall;
    TextStyle? dividerStyleDefault =
        dividerStyle ??
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
