import 'dart:math' as math;
import 'dart:ui';

import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// [PopupMenu] allows you to easily create custom Popup Menus
class PopupMenu extends StatefulWidget {
  const PopupMenu({
    Key? key,
    required this.button,
    this.children,
    this.redirect,
    this.brightness,
  }) : super(key: key);
  final ButtonOptions button;
  final Brightness? brightness;

  /// [children]
  /// [ButtonOptions], [PopupMenuDivider] or [PopupMenuEntry<String>] for custom implementation
  final List<dynamic>? children;
  final Function? redirect;

  @override
  State<PopupMenu> createState() => _PopupMenuState();
}

class _PopupMenuState extends State<PopupMenu> {
  final popupButtonKey = GlobalKey<State>();

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    final Brightness _brightness =
        widget.brightness ?? theme.colorScheme.brightness;
    final bool isDark = _brightness == Brightness.dark;
    List<PopupMenuEntry<String>> buttons = [];
    Color _colorBase = theme.colorScheme.primary;
    Color _colorIcon = theme.colorScheme.secondary;
    Color _colorBaseImportant = theme.colorScheme.secondaryVariant;
    if (isDark) {
      _colorBase = Colors.white;
      // _colorIcon = Colors.white;
      // _colorIcon = theme.colorScheme.primary;
      // _colorBaseImportant = Colors.white;
    }
    TextStyle? textStyle = textTheme.subtitle2;
    TextStyle? textStyleImportant = textStyle?.copyWith(
        fontWeight: FontWeight.w700, color: _colorBaseImportant);
    double? _height = kIsWeb ? 34.00 : kMinInteractiveDimension;

    if (widget.children != null) {
      for (int i = 0; i < widget.children!.length; i++) {
        dynamic item = widget.children![i];
        bool enabled = item.onTap != null || item.path != null;
        if (item is ButtonOptions) {
          Widget _content = Text(
            item.label,
            style: textStyle,
          );
          if (item.important == true) {
            _content = Text(item.label, style: textStyleImportant);
          }
          buttons.add(PopupMenuItem<String>(
            height: _height,
            enabled: enabled,
            value: item.path ?? item.label,
            child: _content,
            textStyle: textStyle,
            onTap: () {
              if (item.onTap != null) item.onTap!();
            },
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
          color: _colorIcon,
        ),
        SizedBox(width: gap),
      ]);
    }
    mainButtonWidgets.addAll([
      Flexible(
          child: Text(
        widget.button.label,
        style: textStyle?.copyWith(color: _colorBase),
      )),
    ]);
    if (widget.children != null) {
      mainButtonWidgets.addAll([
        SizedBox(width: gap),
        Icon(
          Icons.arrow_drop_down,
          color: _colorBase,
        ),
      ]);
    }
    Widget _mainButton = TextButton(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: mainButtonWidgets,
        ),
      ),
      onPressed: () {
        if (widget.button.path != null) {
          Navigator.pushNamed(context, widget.button.path!);
        }
      },
    );
    if (widget.children == null) return _mainButton;
    return PopupMenuButton<String>(
      offset: Offset(0, 40),
      key: popupButtonKey,
      initialValue: "/",
      onSelected: (value) {
        if (value.startsWith("/")) Navigator.pushNamed(context, value);
      },
      child: MouseRegion(
        child: _mainButton,
        cursor: SystemMouseCursors.click,
        onHover: (event) {
          dynamic state = popupButtonKey.currentState;
          state.showButtonMenu();
        },
      ),
      itemBuilder: (BuildContext context) => buttons,
    );
  }
}
