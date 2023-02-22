import 'package:flutter/material.dart';

import '../helper/options.dart';
import 'smart_image.dart';

/// Navigation Breadcrumbs provides a useful way to display navigation routes
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({
    Key? key,
    required this.buttons,
    this.buttonStyle,
    this.dividerStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
    this.textStyle,
  }) : super(key: key);

  final List<ButtonOptions> buttons;
  final ButtonStyle? buttonStyle;
  final TextStyle? dividerStyle;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    List<Widget> items = [];
    TextStyle? textStyleDefault = textStyle ?? textTheme.bodySmall;
    TextStyle? dividerStyleDefault = dividerStyle ?? textTheme.bodySmall;
    for (int i = 0; i < buttons.length; i++) {
      ButtonOptions button = buttons[i];
      bool clickable = button.path != null || button.onTap != null;
      VoidCallback? onPressed;
      if (clickable) {
        onPressed = () {
          if (button.onTap != null) button.onTap!;
          if (button.path != null) {
            Navigator.of(context).popAndPushNamed(button.path!);
          }
        };
      }
      if (button.icon != null || button.image != null) {
        late Widget iconButton;
        if (button.icon != null) {
          iconButton = Icon(button.icon);
        }
        if (button.image != null) {
          iconButton = CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: ClipOval(child: SmartImage(url: button.image)),
          );
        }
        items.add(
          TextButton.icon(
            icon: iconButton,
            onPressed: onPressed,
            label: Text(button.label, style: textStyleDefault),
            style: buttonStyle,
          ),
        );
      } else {
        items.add(
          TextButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Text(button.label, style: textStyleDefault),
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
