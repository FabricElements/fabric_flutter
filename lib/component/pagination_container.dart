import 'package:flutter/material.dart';

import '../helper/log_color.dart';

class PaginationContainer extends StatefulWidget {
  const PaginationContainer({
    super.key,
    required this.paginate,
    required this.itemBuilder,
    this.primary = false,
    this.reverse = false,
    this.padding = EdgeInsets.zero,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 5,
    this.empty = const Center(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox.square(
          dimension: 32,
          child: Icon(Icons.remove),
        ),
      ),
    ),
    this.error = const Center(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Error Loading!'),
      ),
    ),
    this.loading = const Center(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox.square(
          dimension: 32,
          child: Icon(Icons.hourglass_bottom),
        ),
      ),
    ),
    required this.stream,
    this.initialData,
    this.clipBehavior = Clip.hardEdge,
    this.shrinkWrap = false,
  });

  final Widget Function(
    BuildContext context,
    int index,
    dynamic data,
  ) itemBuilder;
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
  final ScrollController _controller = ScrollController();
  late String? error;
  List<dynamic> data = [];

  @override
  void initState() {
    /// Initial state
    end = false;
    error = null;
    data = widget.initialData ?? [];
    // Always set loading to true when the initial data is empty
    loading = data.isEmpty;

    /// Scroll controller
    _controller.addListener(() async {
      if (end) return;
      bool isBottom =
          _controller.position.atEdge && _controller.position.pixels != 0;
      if (!isBottom) return;
      loading = true;
      if (mounted) setState(() {});
      try {
        error = null;
        final data = await widget.paginate();
        end = data == null || data.isEmpty;
      } catch (e) {
        error = e.toString();
        debugPrint(LogColor.error(e));
      }
      loading = false;
      if (mounted) setState(() {});
    });

    /// Get data from stream
    widget.stream.listen((event) {
      final eventData = event != null ? event as List<dynamic> : null;
      data = eventData ?? widget.initialData ?? [];
      loading = eventData == null;
      if (widget.initialData != null && widget.initialData!.isNotEmpty) {
        loading = false;
      }
      if (mounted) setState(() {});
    }).onError((e) {
      error = e.toString();
      loading = false;
      if (mounted) setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.stream.drain();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int total = data.length;
    late Widget content;
    if (error != null) {
      content = SingleChildScrollView(
        child: widget.error,
      );
    } else if (loading && data.isEmpty) {
      content = SingleChildScrollView(
        child: widget.loading,
      );
    } else if (total == 0) {
      content = SingleChildScrollView(
        child: widget.empty,
      );
    } else {
      content = Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        controller: _controller,
        child: ListView.builder(
          key: const PageStorageKey('pagination-container-scroll'),
          restorationId: 'pagination-container',
          clipBehavior: widget.clipBehavior,
          primary: widget.primary,
          cacheExtent: widget.cacheExtent,
          controller: _controller,
          itemCount: loading ? total + 1 : total,
          padding: widget.padding,
          shrinkWrap: widget.shrinkWrap,
          itemBuilder: (BuildContext context, int index) {
            if (index < total) {
              return widget.itemBuilder(
                context,
                index,
                data[index],
              );
            } else {
              return SizedBox(
                width: double.maxFinite,
                child: widget.loading,
              );
            }
          },
          reverse: widget.reverse,
          scrollDirection: widget.scrollDirection,
        ),
      );
    }

    return content;
  }
}
