import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';

class Tabs extends StatelessWidget {
  const Tabs({
    Key? key,
    required this.tabs,
  }) : super(key: key);
  final List<ButtonOptions> tabs;

  @override
  Widget build(BuildContext context) {
    AppLocalizations locales = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    TabBarTheme tbTheme = theme.tabBarTheme;

    List<Widget> tabList = List.generate(tabs.length, (i) {
      final option = tabs[i];
      bool hasAction = option.path != null || option.onTap != null;
      TextStyle? labelStyle = (option.selected
              ? tbTheme.labelStyle ?? theme.primaryTextTheme.bodyText1
              : tbTheme.unselectedLabelStyle ??
                  theme.primaryTextTheme.bodyText1)
          ?.copyWith(
        color:
            option.selected ? tbTheme.labelColor : tbTheme.unselectedLabelColor,
      );
      Color? indicatorColor = option.selected ? theme.indicatorColor : null;

      // Color? background = tbTheme.indicator?.color;
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
