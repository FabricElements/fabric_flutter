import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../helper/options.dart';

/// [SmartButton] allows you to easily create buttons or/and custom Popup Menus
class SmartButton extends StatefulWidget {
  const SmartButton({
    super.key,
    required this.button,
    this.children,
    this.redirect,
    this.brightness,
    this.pop = false,
  });

  final ButtonOptions button;
  final Brightness? brightness;
  final bool pop;

  /// [children]
  /// [ButtonOptions], [PopupMenuDivider] or [PopupMenuEntry<String>] for custom implementation
  final List<dynamic>? children;
  final Function? redirect;

  @override
  State<SmartButton> createState() => _SmartButtonState();
}

class _SmartButtonState extends State<SmartButton> {
  final popupButtonKey = GlobalKey<State>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final Brightness brightness =
        widget.brightness ?? theme.colorScheme.brightness;
    final bool isDark = brightness == Brightness.dark;
    List<PopupMenuEntry<String>> buttons = [];
    Color colorBase = theme.colorScheme.primary;
    Color colorIcon = theme.colorScheme.secondary;
    Color colorBaseImportant = theme.colorScheme.secondaryContainer;
    Color colorBaseSelected = theme.colorScheme.primary;
    if (isDark) {
      colorBase = Colors.white;
      // _colorIcon = Colors.white;
      // _colorIcon = theme.colorScheme.primary;
      // _colorBaseImportant = Colors.white;
    }
    TextStyle? textStyle = textTheme.titleSmall;
    double? height = kIsWeb ? 34.00 : kMinInteractiveDimension;

    if (widget.children != null) {
      for (int i = 0; i < widget.children!.length; i++) {
        dynamic item = widget.children![i];
        bool enabled = item.onTap != null || item.path != null;
        if (item is ButtonOptions) {
          TextStyle? textStyle0 = textStyle;
          if (item.selected) {
            textStyle0 = textStyle?.copyWith(color: colorBaseSelected);
          }
          if (item.important) {
            textStyle0 = textStyle?.copyWith(
                color: colorBaseImportant, fontWeight: FontWeight.w700);
          }
          Widget content = Text(
            item.label,
            style: textStyle0,
          );
          buttons.add(PopupMenuItem<String>(
            height: height,
            enabled: enabled,
            value: item.path ?? item.label,
            textStyle: textStyle,
            onTap: () {
              if (item.onTap != null) item.onTap!();
            },
            child: content,
          ));
        } else if (item is PopupMenuDivider) {
          buttons.add(item);
        } else if (item is PopupMenuEntry<String>) {
          buttons.add(item);
        }
      }
    }
    final double scale = MediaQuery.maybeOf(context)?.textScaleFactor ?? 1;
    final double gap =
        scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!;

    /// Main Button
    List<Widget> mainButtonWidgets = [];
    if (widget.button.icon != null) {
      mainButtonWidgets.addAll([
        Icon(
          widget.button.icon,
          color: colorIcon,
        ),
        SizedBox(width: gap),
      ]);
    }
    mainButtonWidgets.addAll([
      Flexible(
        child: Text(
          widget.button.label,
          style: textStyle?.copyWith(color: colorBase),
        ),
      ),
    ]);
    if (widget.children != null) {
      mainButtonWidgets.addAll([
        SizedBox(width: gap),
        Icon(
          Icons.arrow_drop_down,
          color: colorBase,
        ),
      ]);
    }
    Widget mainButton = TextButton(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: mainButtonWidgets,
        ),
      ),
      onPressed: () {
        if (widget.button.path != null) {
          if (widget.button.onTap != null) widget.button.onTap!();
          if (widget.pop) {
            Navigator.popAndPushNamed(context, widget.button.path!);
          } else {
            Navigator.pushNamed(context, widget.button.path!);
          }
        }
      },
    );
    if (widget.children == null) return mainButton;
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      key: popupButtonKey,
      initialValue: '/',
      onSelected: (value) {
        if (value.startsWith('/')) {
          if (widget.pop) {
            Navigator.popAndPushNamed(context, value);
          } else {
            Navigator.pushNamed(context, value);
          }
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (event) {
          dynamic state = popupButtonKey.currentState;
          state.showButtonMenu();
        },
        child: mainButton,
      ),
      itemBuilder: (BuildContext context) => buttons,
    );
  }
}
