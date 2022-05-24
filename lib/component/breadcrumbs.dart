import 'package:flutter/material.dart';

import '../helper/options.dart';

/// Navigation [Breadcrumbs] provides a useful way to display navigation routes
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
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    List<Widget> items = [];
    TextStyle? _textStyle = textStyle ?? textTheme.caption;
    TextStyle? _dividerStyle = dividerStyle ?? textTheme.caption;
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
      if (button.icon != null) {
        items.add(
          TextButton.icon(
            icon: Icon(button.icon),
            onPressed: onPressed,
            label: Text(button.label, style: _textStyle),
            style: buttonStyle,
          ),
        );
      } else {
        items.add(
          TextButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Text(button.label, style: _textStyle),
          ),
        );
      }
      if (i < (buttons.length - 1)) {
        items.add(Text('/', style: _dividerStyle));
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
