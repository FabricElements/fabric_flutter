import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../helper/options.dart';

/// Builds a text button that can also expose a popup menu of related actions.
///
/// [SmartButton] lets callers describe primary and secondary actions with the
/// same [ButtonOptions] model. It is useful in app bars, toolbars, and compact
/// action rows where a single button may either navigate immediately or expand
/// into a menu depending on the provided configuration.
class SmartButton extends StatefulWidget {
  /// Creates a [SmartButton] with a required primary [button] definition.
  ///
  /// Provide [children] to turn the button into a popup-menu trigger. When
  /// [pop] is `true`, route changes replace the current route instead of pushing
  /// on top of it.
  const SmartButton({
    super.key,
    required this.button,
    this.children,
    this.redirect,
    this.brightness,
    this.pop = false,
    this.semanticsLabel,
    this.automationKey,
    this.semanticHint,
  });

  /// Describes the main visible button label, icon, and optional route.
  final ButtonOptions button;

  /// Overrides the brightness used to derive text and icon colors.
  final Brightness? brightness;

  /// Determines whether navigation should use `popAndPushNamed` instead of `pushNamed`.
  final bool pop;

  /// Supplies popup-menu entries shown after activating the main button.
  ///
  /// Supported values include [ButtonOptions], [PopupMenuDivider], and custom
  /// [PopupMenuEntry<String>] instances for advanced menu content.
  final List<dynamic>? children;

  /// Provides a reserved hook for external redirect flows.
  final Function? redirect;

  /// Overrides the label exposed to accessibility tools and autonomous agents.
  ///
  /// Falls back to [ButtonOptions.label] from [button] when `null`.
  final String? semanticsLabel;

  /// Assigns a deterministic identifier to the semantics node.
  ///
  /// Use a value following the `[RouteName]_[ContextBlock]_[ComponentType]_[ActionOrId]`
  /// naming convention. Maps to [Semantics.identifier] in the accessibility tree.
  final String? automationKey;

  /// Provides structural, non-visual instructions to autonomous agents.
  ///
  /// Maps to [Semantics.hint] in the accessibility tree.
  final String? semanticHint;

  /// Creates the mutable state used to coordinate popup-menu behavior.
  @override
  State<SmartButton> createState() => _SmartButtonState();
}

/// Holds popup-menu state for [SmartButton].
class _SmartButtonState extends State<SmartButton> {
  /// References the popup button so hover interactions can open its menu.
  final popupButtonKey = GlobalKey<State>();

  /// Builds the main button and, when configured, its popup-menu wrapper.
  ///
  /// The widget adapts its spacing for larger text scales and keeps navigation
  /// decisions local so parent widgets can pass lightweight action metadata.
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
              color: colorBaseImportant,
              fontWeight: FontWeight.w700,
            );
          }
          Widget content = Text(item.label, style: textStyle0);
          buttons.add(
            PopupMenuItem<String>(
              height: height,
              enabled: enabled,
              value: item.path ?? item.label,
              textStyle: textStyle,
              onTap: () {
                if (item.onTap != null) item.onTap!();
              },
              child: content,
            ),
          );
        } else if (item is PopupMenuDivider) {
          buttons.add(item);
        } else if (item is PopupMenuEntry<String>) {
          buttons.add(item);
        }
      }
    }
    // final double scale = MediaQuery.maybeOf(context)?.textScaleFactor ?? 1;
    // TODO: Implement scale when possible
    const double scale = 1;
    final double gap = scale <= 1
        ? 8
        : lerpDouble(8, 4, math.min(scale - 1, 1))!;

    /// Main Button
    List<Widget> mainButtonWidgets = [];
    if (widget.button.icon != null) {
      mainButtonWidgets.addAll([
        Icon(widget.button.icon, color: colorIcon),
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
        Icon(Icons.arrow_drop_down, color: colorBase),
      ]);
    }
    Widget mainButton = TextButton(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(mainAxisSize: MainAxisSize.min, children: mainButtonWidgets),
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
    if (widget.children == null) return _withSemantics(mainButton);
    return _withSemantics(
      PopupMenuButton<String>(
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
      ),
    );
  }

  /// Wraps [child] in a [Semantics] container with label, identifier, and enabled state.
  ///
  /// Uses [SmartButton.semanticsLabel] when provided; falls back to
  /// [ButtonOptions.label] from [widget.button]. The [enabled] flag reflects
  /// whether the button has an actionable [ButtonOptions.path] or
  /// [ButtonOptions.onTap].
  Widget _withSemantics(Widget child) {
    final bool isActionable =
        widget.button.path != null || widget.button.onTap != null;
    return Semantics(
      label: widget.semanticsLabel ?? widget.button.label,
      identifier: widget.automationKey,
      hint: widget.semanticHint,
      enabled: isActionable,
      container: true,
      child: child,
    );
  }
}
