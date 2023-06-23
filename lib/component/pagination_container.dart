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
  late Stream<dynamic> stream;
  late List<dynamic>? initialData;

  _start() {
    end = false;
    loading = false;
    error = null;
    stream = widget.stream;
    initialData = widget.initialData;
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
        if (kDebugMode) print(e);
      }
      loading = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    _start();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    stream.drain();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PaginationContainer oldWidget) {
    stream.drain();
    _start();
    if (mounted) setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Scaffold(body: widget.error, primary: false);
    return StreamBuilder(
      stream: stream,
      initialData: initialData,
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        List<dynamic>? data = snapshot.data;
        if (snapshot.hasError) return widget.error;
        bool connected = false;
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            break;
          case ConnectionState.active:
          case ConnectionState.done:
            connected = true;
            if (snapshot.data != null) {
              data = snapshot.data as List<dynamic>;
            }
        }
        int total = data?.length ?? 0;
        if (total == 0) {
          return widget.empty;
        }
        if (data == null && !connected) {
          return widget.loading;
        }
        return Scrollbar(
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          controller: _controller,
          child: ListView.builder(
            clipBehavior: widget.clipBehavior,
            primary: widget.primary,
            cacheExtent: widget.cacheExtent,
            controller: _controller,
            itemCount: loading ? total + 1 : total,
            padding: widget.padding,
            shrinkWrap: widget.shrinkWrap,
            itemBuilder: (BuildContext context, int index) {
              if (index < total) {
                return widget.itemBuilder(context, data![index]);
              } else {
                return widget.loading;
              }
            },
            reverse: widget.reverse,
            scrollDirection: widget.scrollDirection,
          ),
        );
      },
    );
  }
}
