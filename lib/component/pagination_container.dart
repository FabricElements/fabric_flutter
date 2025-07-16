import 'package:fabric_flutter/component/content_container.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
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
    this.cacheExtent = 1000,
    this.empty,
    this.loading,
    this.end,
    required this.stream,
    this.initialData,
    this.clipBehavior = Clip.hardEdge,
    this.shrinkWrap = false,
  });

  final Widget Function(BuildContext context, int index, dynamic data)
  itemBuilder;
  final bool primary;
  final bool reverse;
  final EdgeInsetsGeometry padding;
  final Axis scrollDirection;
  final double cacheExtent;
  final Widget? empty;
  final Widget? loading;
  final Widget? end;
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
    // Always set loading to true when the initial data is null
    loading = widget.initialData == null;

    /// Scroll controller
    _controller.addListener(() async {
      bool isBottom =
          _controller.position.atEdge && _controller.position.pixels != 0;
      // Do nothing if any of these conditions are met
      if (!isBottom) return;
      if (end) return;
      if (loading) return;
      loading = true;
      if (mounted) setState(() {});
      try {
        error = null;
        final paginationData = await widget.paginate();
        end = paginationData == null || paginationData.isEmpty;
      } catch (e) {
        error = e.toString();
        debugPrint(LogColor.error(e));
      }
      loading = false;
      if (mounted) setState(() {});
    });

    /// Get data from stream
    widget.stream
        .listen((event) {
          loading = false;
          final eventData = event != null ? event as List<dynamic> : null;
          data = eventData ?? widget.initialData ?? [];
          end = false;
          if (mounted) setState(() {});
        })
        .onError((e) {
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
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    int total = data.length;
    final widgetEmpty =
        widget.empty ??
        Card(
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Icon(Icons.info),
            title: Text(locales.get('label--nothing-here-yet')),
          ),
        );
    final widgetLoading =
        widget.loading ??
        Card(
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: const CircularProgressIndicator(),
            title: Text(locales.get('label--loading')),
          ),
        );
    final widgetEnd =
        widget.end ??
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: kMinInteractiveDimension * 2),
            child: Icon(
              Icons.remove,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        );

    late Widget content;
    if (loading && data.isEmpty) {
      content = SingleChildScrollView(
        primary: false,
        padding: widget.padding,
        child: ContentContainer(child: widgetLoading),
      );
    } else if (total == 0) {
      content = SingleChildScrollView(
        primary: false,
        padding: widget.padding,
        child: ContentContainer(child: widgetEmpty),
      );
    } else {
      int totalCount = total;
      if (loading || error != null || end) totalCount++;
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
          itemCount: totalCount,
          padding: widget.padding,
          shrinkWrap: widget.shrinkWrap,
          itemBuilder: (BuildContext context, int index) {
            if (index < total) {
              return widget.itemBuilder(context, index, data[index]);
            }
            if (error != null) {
              return ContentContainer(
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: Icon(Icons.error),
                    title: Text(error!),
                    textColor: theme.colorScheme.onErrorContainer,
                    iconColor: theme.colorScheme.onErrorContainer,
                  ),
                ),
              );
            } else if (loading) {
              return ContentContainer(child: widgetLoading);
            } else if (end) {
              return ContentContainer(child: widgetEnd);
            } else {
              return SizedBox();
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
