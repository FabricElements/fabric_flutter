import 'package:flutter/material.dart';

import '../helper/options.dart';

/// Displays a scrollable [TabBar] driven by a list of [ButtonOptions].
///
/// This widget centralizes tab presentation and navigation so screens can reuse
/// the same option model for both named-route navigation and local callbacks.
/// It expects one incoming option to be marked as selected so rebuilds can keep
/// the visible tab aligned with external application state.
class Tabs extends StatefulWidget {
  /// Creates a [Tabs] widget from the provided tab definitions.
  ///
  /// The [tabs] collection supplies the labels, icons, selection state, and
  /// optional actions that define each rendered tab.
  const Tabs({super.key, required this.tabs});

  /// Stores the tab definitions rendered by [Tabs].
  ///
  /// Each [ButtonOptions] entry can provide a label, icon, selected state,
  /// callback, and named route destination for a single tab.
  final List<ButtonOptions> tabs;

  /// Creates the mutable state that manages tab selection for [Tabs].
  ///
  /// The returned [_TabsState] owns the [TabController] used to keep the
  /// rendered [TabBar] synchronized with [tabs].
  @override
  State<Tabs> createState() => _TabsState();
}

/// Manages the [TabController] used by [Tabs].
///
/// This state object creates and disposes the controller with the widget
/// lifecycle, then updates its selected index from the current
/// [ButtonOptions] list during each build.
class _TabsState extends State<Tabs> with SingleTickerProviderStateMixin {
  /// Stores the [TabController] that drives the rendered [TabBar].
  ///
  /// The controller length matches the current [Tabs.tabs] list so tap and
  /// selection state stay aligned with the available tab options.
  late TabController _tabController;

  /// Initializes the [TabController] when the state enters the tree.
  ///
  /// Using [SingleTickerProviderStateMixin] lets the controller receive the
  /// required ticker from this state object.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: widget.tabs.length);
  }

  /// Releases the [TabController] before the state is removed.
  ///
  /// Disposing the controller prevents ticker and animation resources from
  /// remaining active after [Tabs] leaves the widget tree.
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Builds a scrollable [TabBar] for the current [ButtonOptions] list.
  ///
  /// The returned widget updates the controller index from the selected option,
  /// then forwards taps to an optional callback before navigating to a named
  /// route when [ButtonOptions.path] is not `null`.
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
