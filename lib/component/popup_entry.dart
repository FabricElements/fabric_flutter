import 'package:flutter/material.dart';

/// PopupEntry used for popup options without value
class PopupEntry extends PopupMenuEntry<Never> {
  /// By default, the divider has a height of 16 logical pixels.
  const PopupEntry({
    super.key,
    this.height = kMinInteractiveDimension,
    required this.child,
  });

  @override
  final double height;

  @override
  bool represents(void value) => false;

  final Widget child;

  @override
  State<StatefulWidget> createState() => _PopupEntryState();
}

class _PopupEntryState extends State<PopupEntry> {
  late Widget child;

  @override
  void initState() {
    child = widget.child;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
