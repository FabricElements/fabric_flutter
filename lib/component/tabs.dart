import 'package:flutter/material.dart';

import '../helper/options.dart';

/// Displays a scrollable [TabBar] driven by a list of [ButtonOptions].
///
/// This widget centralizes tab presentation and navigation so screens can reuse
/// the same option model for both routing and local callbacks. It expects the
/// incoming list to mark the currently selected tab, which lets rebuilds keep
/// the controller aligned with external application state.
class Tabs extends StatefulWidget {
  /// Creates a [Tabs] widget from the provided tab definitions.
  const Tabs({super.key, required this.tabs});

  /// Defines the visible tabs, their icons, and any navigation or tap behavior.
  final List<ButtonOptions> tabs;

  /// Creates the mutable tab-controller state for [Tabs].
  @override
  State<Tabs> createState() => _TabsState();
}

/// Holds the [TabController] used by [Tabs].
class _TabsState extends State<Tabs> with SingleTickerProviderStateMixin {
  /// Keeps the [TabBar] selection synchronized with the incoming [ButtonOptions].
  late TabController _tabController;

  /// Initializes the [TabController] once the state object joins the tree.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: widget.tabs.length);
  }

  /// Releases the [TabController] when [Tabs] leaves the widget tree.
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Builds a scrollable [TabBar] and forwards tab selection to callbacks or routes.
  ///
  /// Routing happens after any tab-specific callback so parent widgets can update
  /// local state before navigation occurs.
  @override
  Widget build(BuildContext context) {
    List<Tab> tabList = List.generate(widget.tabs.length, (i) {
      final option = widget.tabs[i];
      return Tab(
        text: option.label,
        icon: option.icon != null ? Icon(option.icon) : null,
      );
    });
    final selected = widget.tabs.indexWhere((element) => element.selected);
    _tabController.index = selected;
    return TabBar(
      controller: _tabController,
      tabs: tabList,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      onTap: (index) {
        final option = widget.tabs[index];
        if (option.onTap != null) option.onTap!();
        if (option.path != null) {
          Navigator.of(context).popAndPushNamed(option.path!);
        }
      },
    );
  }
}
