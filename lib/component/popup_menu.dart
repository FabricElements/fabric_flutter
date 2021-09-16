import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';

/// [PopupMenu] allows you to easily create custom Popup Menus
class PopupMenu extends StatefulWidget {
  const PopupMenu({
    Key? key,
    required this.button,
    this.children,
    this.redirect,
  }) : super(key: key);
  final ButtonOptions button;

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
    List<PopupMenuEntry<String>> buttons = [];
    if (widget.children != null) {
      for (int i = 0; i < widget.children!.length; i++) {
        dynamic item = widget.children![i];
        if (item is ButtonOptions) {
          buttons.add(PopupMenuItem<String>(
            value: item.path ?? item.label,
            child: Text(item.label),
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
    return PopupMenuButton<String>(
      offset: Offset(0, 40),
      key: popupButtonKey,
      initialValue: "/",
      onSelected: (value) {
        if (value.startsWith("/")) Navigator.pushNamed(context, value);
      },
      child: MouseRegion(
        child: TextButton(
          child: Text(widget.button.label),
          onPressed: () {
            if (widget.button.path != null)
              Navigator.pushNamed(context, widget.button.path!);
          },
        ),
        cursor: SystemMouseCursors.click,
        onHover: (event) {
          dynamic state = popupButtonKey.currentState;
          state.showButtonMenu();
        },
      ),
      itemBuilder: (BuildContext context) {
        return buttons;
      },
    );
  }
}
