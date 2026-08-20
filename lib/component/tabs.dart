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
/// [ButtonOptions] list during each build. [TickerProviderStateMixin] is used
/// instead of the single-ticker variant because the controller is recreated
/// whenever the number of tabs changes, which requires a second ticker.
class _TabsState extends State<Tabs> with TickerProviderStateMixin {
  /// Stores the [TabController] that drives the rendered [TabBar].
  ///
  /// The controller length matches the current [Tabs.tabs] list so tap and
  /// selection state stay aligned with the available tab options.
  late TabController _tabController;

  /// Tracks the reduced-motion preference the current [_tabController] was
  /// built with, so [didChangeDependencies] only recreates it when the
  /// platform setting actually changes.
  bool? _disableAnimations;

  /// Initializes the [TabController] when the state enters the tree.
  ///
  /// Using [TickerProviderStateMixin] lets the controller receive the
  /// required ticker from this state object.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      vsync: this,
      length: widget.tabs.length,
      initialIndex: _selectedIndex,
    );
  }

  /// Resolves the index of the currently selected tab.
  ///
  /// [ButtonOptions.selected] is optional, so `indexWhere` can return `-1` when
  /// no entry is marked. That value is not a valid [TabController] index and
  /// would throw, so it is clamped to the first tab. An empty tab list resolves
  /// to `0` as well, matching the zero-length controller.
  int get _selectedIndex {
    final selected = widget.tabs.indexWhere((element) => element.selected);
    return selected < 0 ? 0 : selected;
  }

  /// Rebuilds the [TabController] when the number of tabs changes.
  ///
  /// A [TabController] has a fixed length, so a parent that adds or removes tabs
  /// would otherwise leave the controller describing a stale tab count and trip
  /// a framework assertion inside [TabBar].
  @override
  void didUpdateWidget(covariant Tabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length == widget.tabs.length) return;
    _tabController.dispose();
    _tabController = TabController(
      vsync: this,
      length: widget.tabs.length,
      initialIndex: _selectedIndex,
    );
  }

  /// Rebuilds [_tabController] with an animation duration that respects the
  /// platform's reduced-motion preference.
  ///
  /// When [MediaQuery.disableAnimationsOf] reports that animations should be
  /// disabled, the tab indicator jumps instantly instead of sliding, while the
  /// currently selected index and length are preserved.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    final previousIndex = _tabController.index;
    final previousLength = _tabController.length;
    _tabController.dispose();
    _tabController = TabController(
      vsync: this,
      length: previousLength,
      initialIndex: previousIndex < previousLength ? previousIndex : 0,
      animationDuration: disableAnimations ? Duration.zero : kTabScrollDuration,
    );
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
        icon: option.icon != null ? Icon(option.icon) : null,
        // A custom child (instead of `text:`) lets the label ellipsize so a
        // long label or an opted-in OS text scale cannot overflow the tab.
        // `Tab` centers its child in a box, so the text must not be wrapped in
        // a `Flexible`.
        child: Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    });
    final selected = _selectedIndex;
    if (widget.tabs.isNotEmpty) _tabController.index = selected;
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
