import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import 'content_container.dart';

/// Renders an infinitely scrollable list that reacts to streamed page results.
///
/// The widget listens to [stream] for authoritative list snapshots and requests more
/// data through [paginate] when the user scrolls to the trailing edge. This separation
/// keeps pagination side effects outside the widget while still preserving scroll state,
/// loading feedback, and empty or error placeholders inside the UI lifecycle.
class PaginationContainer extends StatefulWidget {
  /// Creates a paginated list shell that can show loading, empty, and terminal states.
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
    this.initialScrollOffset = 0.0,
    this.onScrollOffsetChanged,
    this.top,
    this.bottom,
  });

  /// Builds each visible item from its index and the matching streamed data element.
  final Widget Function(BuildContext context, int index, dynamic data)
  itemBuilder;
  /// Forwards whether this scroll view should be the primary scrollable in scope.
  final bool primary;
  /// Reverses the order in which list items and scroll direction are presented.
  final bool reverse;
  /// Insets the list content and the fallback placeholder layouts.
  final EdgeInsetsGeometry padding;
  /// Chooses whether pagination proceeds vertically or horizontally.
  final Axis scrollDirection;
  /// Controls how far ahead the list prebuilds children for smoother scrolling.
  final double cacheExtent;
  /// Overrides the widget shown when no items are currently available.
  final Widget? empty;
  /// Overrides the widget shown while the initial page is being fetched.
  final Widget? loading;
  /// Overrides the footer shown after pagination reaches the final page.
  final Widget? end;
  /// Emits the latest list snapshot that should replace the current item collection.
  final Stream<dynamic> stream;
  /// Seeds the list before the first stream event arrives, preserving perceived continuity.
  final List<dynamic>? initialData;
  /// Defines how overflowing children are clipped inside the scrolling list.
  final Clip clipBehavior;
  /// Shrinks the scroll view to its contents when embedding it in another layout.
  final bool shrinkWrap;
  /// Inserts a widget before the first list item or placeholder content.
  final Widget? top;
  /// Inserts a widget after the last list item or placeholder content.
  final Widget? bottom;

  /// Restores a previously captured scroll offset when rebuilding the list.
  final double initialScrollOffset;

  /// Reports scroll offset changes so parents can persist or react to scroll position.
  final Function(double offset)? onScrollOffsetChanged;

  /// Requests the next page when the user reaches the current trailing edge.
  final Future<dynamic> Function() paginate;

  /// Creates the state that coordinates scroll events, stream updates, and footers.
  @override
  State<PaginationContainer> createState() => _PaginationContainerState();
}

/// Tracks pagination progress, transient errors, and scroll restoration state.
class _PaginationContainerState extends State<PaginationContainer> {
  /// Marks whether the most recent pagination request indicated there is no more data.
  late bool end;
  /// Marks whether the widget is currently awaiting initial or subsequent data.
  late bool loading;
  /// Tracks whether the current scroll position has reached the trailing edge.
  late bool isBottom;

  // Inside your Widget
  /// Owns scroll position so the widget can detect pagination thresholds and restore offsets.
  late ScrollController _controller;
  /// Stores the latest pagination or stream error for footer presentation.
  late String? error;
  /// Holds the most recent list snapshot emitted by [PaginationContainer.stream].
  List<dynamic> data = [];

  /// Starts listening to scroll and stream updates after insertion into the tree.
  @override
  void initState() {
    super.initState();

    /// Initial state
    end = false;
    error = null;
    data = widget.initialData ?? [];
    isBottom = false;
    // Always set loading to true when the initial data is null
    loading = widget.initialData == null;
    _controller = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );

    /// Scroll controller
    _controller.addListener(() async {
      widget.onScrollOffsetChanged?.call(_controller.offset);
      isBottom =
          _controller.position.atEdge && _controller.position.pixels != 0;
      // if (mounted) setState(() {});
      // Do nothing if any of these conditions are met
      if (!isBottom) return;
      if (end) return;
      if (loading) return;
      loading = true;
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        error = null;
        final paginationData = await widget.paginate();
        end = paginationData == null || paginationData.isEmpty;
      } catch (e) {
        error = e.toString();
        debugPrint(LogColor.error(e));
      }
      await Future.delayed(const Duration(milliseconds: 300));
      loading = false;
      if (mounted) setState(() {});
    });

    /// Get data from stream
    widget.stream
        .listen((event) async {
          loading = true;
          if (mounted) setState(() {});
          final eventData = event != null ? event as List<dynamic> : null;
          data = eventData ?? widget.initialData ?? [];
          end = false;
          loading = false;
          if (mounted) setState(() {});
        })
        .onError((e) {
          error = e.toString();
          loading = false;
          end = false;
          if (mounted) setState(() {});
        });
  }

  /// Releases the scroll controller and drains the stream when the widget is removed.
  @override
  void dispose() {
    _controller.dispose();
    widget.stream.drain();
    super.dispose();
  }

  /// Builds the appropriate loading, empty, populated, or error-aware pagination view.
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    int total = data.length;
    final widgetEmpty =
        widget.empty ??
        Card(
          margin: EdgeInsets.all(16),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Icon(Icons.info),
            title: Text(locales.get('label--nothing-here-yet')),
          ),
        );
    final widgetLoading =
        widget.loading ??
        Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
    final widgetEnd =
        widget.end ??
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: kToolbarHeight),
            child: Icon(
              Icons.remove,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        );

    late Widget content;
    if (loading && data.isEmpty) {
      content = SingleChildScrollView(
        restorationId: 'pagination-container-loading',
        primary: false,
        padding: widget.padding,
        physics: widget.shrinkWrap ? null : const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            ?widget.top,
            ContentContainer(padding: widget.padding, child: widgetLoading),
            ?widget.bottom,
          ],
        ),
      );
    } else if (total == 0) {
      content = SingleChildScrollView(
        restorationId: 'pagination-container-empty',
        primary: false,
        padding: widget.padding,
        physics: widget.shrinkWrap ? null : const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            ?widget.top,
            ContentContainer(padding: widget.padding, child: widgetEmpty),
            ?widget.bottom,
          ],
        ),
      );
    } else {
      int totalCount = total;
      if (loading || error != null || end || isBottom) totalCount++;
      content = Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        controller: _controller,
        child: ListView.builder(
          key: const PageStorageKey('pagination-container-scroll'),
          restorationId: 'pagination-container',
          physics: widget.shrinkWrap ? null : const ClampingScrollPhysics(),
          clipBehavior: widget.clipBehavior,
          primary: widget.primary,
          cacheExtent: widget.cacheExtent,
          controller: _controller,
          itemCount: totalCount,
          padding: widget.padding,
          shrinkWrap: widget.shrinkWrap,
          itemBuilder: (BuildContext context, int index) {
            if (index < total) {
              if (index == 0 && widget.top != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    widget.top!,
                    widget.itemBuilder(context, index, data[index]),
                  ],
                );
              } else if (index == (total - 1) && widget.bottom != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    widget.bottom!,
                    widget.itemBuilder(context, index, data[index]),
                  ],
                );
              }
              return widget.itemBuilder(context, index, data[index]);
            }
            Widget footer = widgetEnd;
            if (error != null) {
              footer = Card(
                margin: EdgeInsets.all(16),
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Icon(Icons.error),
                  title: Text(error!),
                  textColor: theme.colorScheme.onErrorContainer,
                  iconColor: theme.colorScheme.onErrorContainer,
                ),
              );
            } else if (loading) {
              footer = widgetLoading;
            }
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: kToolbarHeight * 2),
              child: ContentContainer(child: footer),
            );
          },
          reverse: widget.reverse,
          scrollDirection: widget.scrollDirection,
        ),
      );
    }

    return content;
  }
}
