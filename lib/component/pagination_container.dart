import 'package:flutter/material.dart';

class PaginationContainer extends StatefulWidget {
  const PaginationContainer({
    Key? key,
    required this.paginate,
    required this.itemBuilder,
    this.primary = true,
    this.padding = EdgeInsets.zero,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 5,
    this.empty = const SizedBox(height: 0, width: 0),
    this.error = const SizedBox(
      height: 30,
      width: 100,
      child: Text('Error Loading Snapshot'),
    ),
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
    required this.stream,
    this.initialData,
  }) : super(key: key);
  final IndexedWidgetBuilder itemBuilder;
  final bool primary;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final double cacheExtent;
  final Widget empty;
  final Widget loading;
  final Widget error;
  final Stream<dynamic> stream;
  final dynamic initialData;

  /// Returns the page
  final Future<dynamic> Function() paginate;

  @override
  State<PaginationContainer> createState() => _PaginationContainerState();
}

class _PaginationContainerState extends State<PaginationContainer> {
  late bool end;
  late bool loading;
  final _controller = ScrollController();

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
      dynamic _data = await widget.paginate();
      end = _data == null || _data.runtimeType == List && _data.length == 0;
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
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.stream,
      initialData: widget.initialData,
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        int total = 0;
        Widget content = widget.loading;
        if (snapshot.hasError) return widget.error;
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            content = content = widget.loading;
            break;
          case ConnectionState.active:
          case ConnectionState.done:
            if (snapshot.data.runtimeType == List) {
              List<dynamic> data = snapshot.data;
              total = data.length;
              if (total == 0) {
                content = Scaffold(body: widget.empty, primary: false);
                break;
              }
              content = Scrollbar(
                isAlwaysShown: true,
                scrollbarOrientation: ScrollbarOrientation.right,
                showTrackOnHover: true,
                interactive: true,
                controller: _controller,
                child: ListView.builder(
                  cacheExtent: widget.cacheExtent,
                  controller: _controller,
                  itemCount: loading ? (total) + 1 : total,
                  padding: widget.padding,
                  itemBuilder: (BuildContext context, int index) {
                    if (index >= total) {
                      return widget.loading;
                    } else {
                      return widget.itemBuilder(context, index);
                    }
                  },
                  scrollDirection: widget.scrollDirection,
                ),
              );
            }
        }
        return content;
      },
    );
  }
}
