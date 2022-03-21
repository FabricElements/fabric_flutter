import 'package:flutter/material.dart';

class PaginationContainer extends StatefulWidget {
  const PaginationContainer({
    Key? key,
    required this.total,
    required this.page,
    required this.callback,
    required this.itemBuilder,
    this.primary = true,
    this.padding = EdgeInsets.zero,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 5,
    this.empty = const SizedBox(height: 0, width: 0),
    this.loading = const Align(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading...',
          ),
        ),
      ),
    ),
  }) : super(key: key);
  final int total;
  final int page;
  final IndexedWidgetBuilder itemBuilder;
  final bool primary;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final double cacheExtent;
  final Widget empty;
  final Widget loading;

  /// Returns the page
  final Future<dynamic> Function(int) callback;

  @override
  State<PaginationContainer> createState() => _PaginationContainerState();
}

class _PaginationContainerState extends State<PaginationContainer> {
  late bool end;
  late bool loading;
  final _controller = ScrollController();
  int loadingPage = 0;

  // bool onThreshold = _controller.offset >=
  //     (_controller.position.maxScrollExtent - height / 2);
  @override
  void initState() {
    end = false;
    loading = false;

    _controller.addListener(() async {
      if (end) return;
      bool isBottom =
          _controller.position.atEdge && _controller.position.pixels != 0;
      if (!isBottom) return;
      loading = true;
      if (mounted) setState(() {});
      int nextPage = widget.page + 1;
      if (loadingPage == nextPage) {
        loading = false;
        if (mounted) setState(() {});
        return;
      }
      loadingPage = nextPage;
      dynamic _data = await widget.callback(nextPage);
      end = _data == null;
      loading = false;
      if (mounted) setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PaginationContainer oldWidget) {
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.total == 0) return Scaffold(body: widget.empty, primary: false);
    return Scrollbar(
      isAlwaysShown: true,
      scrollbarOrientation: ScrollbarOrientation.right,
      showTrackOnHover: true,
      interactive: true,
      controller: _controller,
      child: ListView.builder(
        cacheExtent: widget.cacheExtent,
        controller: _controller,
        itemCount: loading ? (widget.total) + 1 : widget.total,
        padding: widget.padding,
        itemBuilder: (BuildContext context, int index) {
          if (index >= widget.total) return widget.loading;
          return widget.itemBuilder(context, index);
        },
        scrollDirection: widget.scrollDirection,
      ),
    );
  }
}
