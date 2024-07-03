import 'package:flutter/material.dart';

import '../helper/options.dart';

class Tabs extends StatefulWidget {
  const Tabs({
    super.key,
    required this.tabs,
  });

  final List<ButtonOptions> tabs;

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: widget.tabs.length);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
