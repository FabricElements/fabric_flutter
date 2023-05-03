import 'package:flutter/material.dart';

import '../helper/options.dart';

class Tabs extends StatelessWidget {
  const Tabs({
    Key? key,
    required this.tabs,
  }) : super(key: key);
  final List<ButtonOptions> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TabBarTheme tbTheme = theme.tabBarTheme;
    List<Widget> tabList = List.generate(tabs.length, (i) {
      final option = tabs[i];
      bool hasAction = option.path != null || option.onTap != null;
      TextStyle? labelStyle = (option.selected
              ? tbTheme.labelStyle ?? theme.primaryTextTheme.bodyLarge
              : tbTheme.unselectedLabelStyle ??
                  theme.primaryTextTheme.bodyLarge)
          ?.copyWith(
        color:
            option.selected ? tbTheme.labelColor : tbTheme.unselectedLabelColor,
      );
      Color? indicatorColor = option.selected ? theme.indicatorColor : null;
      return Expanded(
        child: RawMaterialButton(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          fillColor: indicatorColor,
          textStyle: labelStyle,
          onPressed: !hasAction
              ? null
              : () {
                  if (option.onTap != null) option.onTap!();
                  if (option.path != null) {
                    Navigator.of(context).popAndPushNamed(option.path!);
                  }
                },
          padding: tbTheme.labelPadding ?? EdgeInsets.zero,
          child: Text(option.label),
        ),
      );
    });

    return Flex(
      direction: Axis.horizontal,
      children: tabList,
    );
  }
}
