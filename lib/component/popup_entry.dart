import 'package:flutter/material.dart';

/// PopupEntry used for popup options without value
class PopupEntry extends PopupMenuEntry<Never> {
  /// Creates a popup menu entry that simply hosts arbitrary widget content.
  ///
  /// Unlike a standard menu item, this entry never resolves a value, which makes
  /// it useful for embedding form controls or custom layouts inside popup menus.
  /// By default, the divider has a height of 16 logical pixels.
  const PopupEntry({
    super.key,
    this.height = kMinInteractiveDimension,
    required this.child,
  });

  /// Defines the vertical space the entry occupies inside the popup menu.
  @override
  final double height;

  /// Indicates that this entry never maps to a selected popup value.
  @override
  bool represents(void value) => false;

  /// The widget subtree displayed inside the popup menu.
  final Widget child;

  /// Creates state that preserves the child widget during popup rebuilds.
  @override
  State<StatefulWidget> createState() => _PopupEntryState();
}

/// Keeps a stable reference to the embedded popup child while the menu is open.
class _PopupEntryState extends State<PopupEntry> {
  /// Stores the widget rendered by this popup entry.
  late Widget child;

  /// Captures the initial child so the popup can return it directly from [build].
  @override
  void initState() {
    super.initState();
    child = widget.child;
  }

  /// Returns the hosted popup content without adding extra layout wrappers.
  @override
  Widget build(BuildContext context) {
    return child;
  }
}
