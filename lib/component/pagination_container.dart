library fabric_flutter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PaginationContainer extends StatefulWidget {
  const PaginationContainer({
    Key? key,
    required this.paginate,
    required this.itemBuilder,
    this.primary = false,
    this.reverse = false,
    this.padding = EdgeInsets.zero,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 5,
    this.empty = const Align(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox.square(
          dimension: 32,
          child: Icon(Icons.check),
        ),
      ),
    ),
    this.error = const Align(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Error Loading Snapshot'),
      ),
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
    this.clipBehavior = Clip.hardEdge,
    this.shrinkWrap = false,
  }) : super(key: key);
  final Widget Function(BuildContext context, dynamic data) itemBuilder;
  final bool primary;
  final bool reverse;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final double cacheExtent;
  final Widget empty;
  final Widget loading;
  final Widget error;
  final Stream<dynamic> stream;
  final List<dynamic>? initialData;
  final Clip clipBehavior;
  final bool shrinkWrap;

  /// Returns the page
  final Future<dynamic> Function() paginate;

  @override
  State<PaginationContainer> createState() => _PaginationContainerState();
}

class _PaginationContainerState extends State<PaginationContainer> {
  late bool end;
  late bool loading;
  final _controller = ScrollController();
  late String? error;

  @override
  void initState() {
    end = false;
    loading = false;
    error = null;
    _controller.addListener(() async {
      if (end) return;
      bool isBottom =
          _controller.position.atEdge && _controller.position.pixels != 0;
      if (!isBottom) return;
      loading = true;
      if (mounted) setState(() {});
      try {
        error = null;
        final _data = await widget.paginate();
        end = _data == null || _data.isEmpty;
      } catch (e) {
        error = e.toString();
        if (kDebugMode) print(e);
      }
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
    if (error != null) return Scaffold(body: widget.error, primary: false);
    return StreamBuilder(
      stream: widget.stream,
      initialData: widget.initialData,
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        int total = 0;
        Widget content = widget.loading;
        List<dynamic>? data = widget.initialData;
        if (snapshot.hasError) return widget.error;
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            content = content = widget.loading;
            break;
          case ConnectionState.active:
          case ConnectionState.done:
            if (snapshot.data != null) {
              data = snapshot.data as List<dynamic>;
            }
        }
        total = data?.length ?? 0;
        if (total == 0 || data == null) {
          content = widget.empty;
        } else {
          // content = Scrollbar(
          //     thumbVisibility: true,
          //     trackVisibility: true,
          //     interactive: true,
          //     controller: _controller,
          //   child: ListView(
          //     clipBehavior: widget.clipBehavior,
          //     primary: widget.primary,
          //     cacheExtent: widget.cacheExtent,
          //     controller: _controller,
          //     shrinkWrap: widget.shrinkWrap,
          //     reverse: widget.reverse,
          //     scrollDirection: widget.scrollDirection,
          //     children: List.generate(
          //         5,
          //         (index) => Container(
          //               height: 200,
          //               color: Colors.orange,
          //               margin: EdgeInsets.all(8),
          //             )),
          //   ),
          // );
          content = Scrollbar(
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            controller: _controller,
            child: ListView.builder(
              clipBehavior: widget.clipBehavior,
              primary: widget.primary,
              cacheExtent: widget.cacheExtent,
              controller: _controller,
              itemCount: loading ? (total) + 1 : total,
              padding: widget.padding,
              shrinkWrap: widget.shrinkWrap,
              itemBuilder: (BuildContext context, int index) {
                if (index >= total) {
                  return widget.loading;
                } else {
                  return widget.itemBuilder(context, data![index]);
                }
              },
              reverse: widget.reverse,
              scrollDirection: widget.scrollDirection,
            ),
          );
        }
        return content;
      },
    );
  }
}
