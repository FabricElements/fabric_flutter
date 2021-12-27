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
      items.add(
        TextButton(
          onPressed: !clickable
              ? null
              : () {
                  if (button.onTap != null) button.onTap!();
                  if (button.path != null) {
                    Navigator.of(context).popAndPushNamed(button.path!);
                  }
                },
          child: Text(button.label, style: _textStyle),
          style: buttonStyle,
        ),
      );
      if (i < (buttons.length - 1)) {
        items.add(Text("/", style: _dividerStyle));
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
        children: items,
        crossAxisAlignment: WrapCrossAlignment.center,
      ),
    );
  }
}