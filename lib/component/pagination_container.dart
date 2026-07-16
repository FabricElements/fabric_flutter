import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import 'content_container.dart';

/// Renders an infinitely scrollable list that reacts to streamed page results.
///
/// The widget listens to [stream] for authoritative list snapshots and requests
/// more data through [paginate] when the user scrolls to the trailing edge.
/// This keeps pagination side effects outside the widget while preserving
/// scroll state, loading feedback, and empty or error placeholders.
class PaginationContainer extends StatefulWidget {
  /// Creates a paginated list shell that can show loading, empty, and terminal
  /// states.
  ///
  /// The constructor accepts presentation overrides and delegates pagination to
  /// [paginate] so the widget remains focused on rendering streamed content.
  const PaginationContainer({
    super.key,
    required this.paginate,
    required this.itemBuilder,
    this.primary = false,
    this.reverse = false,
    this.padding = EdgeInsets.zero,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 2,
    this.empty,
    this.loading,
    this.end,
    required this.stream,
    this.initialData,
    this.clipBehavior = Clip.hardEdge,
    this.shrinkWrap = false,
    this.initialScrollOffset = 0.0,
    this.onScrollOffsetChanged,
    this.onError,
    this.top,
    this.bottom,
  });

  /// Builds each visible item from its index and matching streamed data.
  ///
  /// The callback receives the current [BuildContext], the zero-based item
  /// index, and the corresponding value from the latest list snapshot.
  final Widget Function(BuildContext context, int index, dynamic data)
  itemBuilder;

  /// Determines whether the list should be the primary scroll view in scope.
  ///
  /// Passing `true` lets the surrounding [PrimaryScrollController] own scroll
  /// behaviors such as keyboard scrolling and inherited controller access.
  final bool primary;

  /// Reverses the visual order of items and the scroll direction.
  ///
  /// This is useful for timelines or chat-like layouts where the newest items
  /// should appear nearest the leading viewport edge.
  final bool reverse;

  /// Stores the insets applied to list content and placeholder layouts.
  ///
  /// The same [EdgeInsetsGeometry] is reused for loading and empty states so
  /// those fallbacks align with the populated list.
  final EdgeInsetsGeometry padding;

  /// Selects whether pagination scrolls vertically or horizontally.
  ///
  /// The value affects both the [ListView] axis and how the trailing edge is
  /// interpreted when deciding whether to request another page.
  final Axis scrollDirection;

  /// Creates a cache extent as a multiplier of the viewport's main axis extent.
  ///
  /// The main axis extent is the size of the viewport in its main axis. For
  /// example, for a vertically scrolling list, the main axis extent is the
  /// height of the viewport. If the viewport is 600 logical pixels tall, then
  /// `ScrollCacheExtent.viewport(2.0)` results in a cache extent of 1200 logical
  /// pixels.
  final double cacheExtent;

  /// Provides a custom widget for the empty state.
  ///
  /// When `null`, the widget shows a localized informational card instead.
  final Widget? empty;

  /// Provides a custom widget for the loading state.
  ///
  /// When `null`, the widget shows a [LinearProgressIndicator] wrapped in
  /// padding.
  final Widget? loading;

  /// Provides a custom footer for the terminal pagination state.
  ///
  /// When `null`, the widget shows a minimal centered icon after pagination has
  /// reached the end of the list.
  final Widget? end;

  /// Emits the latest list snapshot that should replace the current items.
  ///
  /// Each event is treated as the authoritative collection, allowing external
  /// state to reset or replace the rendered data at any time.
  final Stream<dynamic> stream;

  /// Seeds the list before the first stream event arrives.
  ///
  /// Providing initial items avoids an initial empty flash and preserves
  /// continuity while the first streamed snapshot is still pending.
  final List<dynamic>? initialData;

  /// Defines how overflowing children are clipped inside the list.
  ///
  /// The value is forwarded to [ListView.builder] so embedding layouts can tune
  /// edge rendering behavior.
  final Clip clipBehavior;

  /// Determines whether the list should size itself to its contents.
  ///
  /// Passing `true` helps when nesting the widget inside another scrollable or
  /// constrained parent.
  final bool shrinkWrap;

  /// Inserts a widget before the first list item or placeholder content.
  ///
  /// The widget is also shown above loading and empty states so surrounding
  /// context remains visible regardless of data availability.
  final Widget? top;

  /// Inserts a widget after the last list item or placeholder content.
  ///
  /// The widget is also shown below loading and empty states to keep trailing
  /// supplementary content consistent.
  final Widget? bottom;

  /// Restores a previously captured scroll offset when rebuilding the list.
  ///
  /// This lets a parent preserve the user's scroll position across widget
  /// recreation.
  final double initialScrollOffset;

  /// Reports scroll offset changes to interested parents.
  ///
  /// The callback can be used to persist the latest offset for later reuse in
  /// [initialScrollOffset].
  final Function(double offset)? onScrollOffsetChanged;

  /// Reports pagination, stream, and scroll-offset-callback errors.
  ///
  /// Optional — errors are always reflected in the inline error footer
  /// regardless of this callback; if omitted, they are only logged via
  /// `debugPrint` under `kDebugMode`.
  final ValueChanged<String>? onError;

  /// Requests the next page after the user reaches the trailing edge.
  ///
  /// Returning `null` or an empty result marks pagination as complete and shows
  /// the terminal footer.
  final Future<dynamic> Function() paginate;

  /// Creates the state that coordinates scroll events, stream updates, and
  /// footers.
  ///
  /// The returned [_PaginationContainerState] owns the scroll controller and
  /// transient pagination flags for this widget instance.
  @override
  State<PaginationContainer> createState() => _PaginationContainerState();
}

/// Stores pagination progress, transient errors, and scroll restoration state.
///
/// The state object reacts to both user scrolling and external stream updates so
/// the widget can merge asynchronous data changes with local loading feedback.
class _PaginationContainerState extends State<PaginationContainer> {
  /// Stores whether the latest pagination request reported no additional data.
  ///
  /// When `true`, the widget stops calling [PaginationContainer.paginate] until
  /// a new stream event resets the flag.
  late bool end;

  /// Stores whether the widget is awaiting initial or subsequent data.
  ///
  /// The flag drives both the initial placeholder and the footer loading state.
  late bool loading;

  /// Stores whether the current scroll position has reached the trailing edge.
  ///
  /// The flag prevents pagination requests until the user actually scrolls to
  /// the end of the active scroll extent.
  late bool isBottom;

  /// Owns scroll position for pagination thresholds and offset restoration.
  ///
  /// The controller also forwards offset changes through
  /// [PaginationContainer.onScrollOffsetChanged].
  late ScrollController _controller;

  /// Stores the latest pagination or stream error message.
  ///
  /// A non-`null` value replaces the standard footer with an error card.
  late String? error;

  /// Stores the most recent list snapshot emitted by [PaginationContainer.stream].
  ///
  /// The list is replaced wholesale whenever the stream publishes a new event.
  List<dynamic> data = [];

  /// Initializes pagination flags and subscribes to scroll and stream updates.
  ///
  /// The method seeds the list from [PaginationContainer.initialData], restores
  /// scroll offset, and wires listeners that update loading, error, and end
  /// state as new pages or streamed snapshots arrive.
  @override
  void initState() {
    super.initState();

    end = false;
    error = null;
    data = widget.initialData ?? [];
    isBottom = false;
    loading = widget.initialData == null;
    _controller = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );

    _controller.addListener(() async {
      try {
        widget.onScrollOffsetChanged?.call(_controller.offset);
      } catch (error) {
        _reportError('PaginationContainer.onScrollOffsetChanged threw: $error');
      }
      isBottom =
          _controller.position.atEdge && _controller.position.pixels != 0;
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
        _reportError(error!);
      }
      await Future.delayed(const Duration(milliseconds: 300));
      loading = false;
      if (mounted) setState(() {});
    });

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
          _reportError(error!);
          loading = false;
          end = false;
          if (mounted) setState(() {});
        });
  }

  /// Reports an error through [PaginationContainer.onError], falling back to
  /// a debug log (under [kDebugMode]) when no handler is registered, or when
  /// the registered handler itself throws.
  void _reportError(String message) {
    if (widget.onError == null) {
      if (kDebugMode) debugPrint(LogColor.error(message));
      return;
    }
    try {
      widget.onError!(message);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(LogColor.error('PaginationContainer.onError threw: $error'));
      }
    }
  }

  /// Releases the scroll controller and drains the stream subscription source.
  ///
  /// Draining the stream helps discard any remaining events after the widget has
  /// been removed from the tree.
  @override
  void dispose() {
    _controller.dispose();
    widget.stream.drain();
    super.dispose();
  }

  /// Builds the loading, empty, populated, or error-aware pagination view.
  ///
  /// The returned widget switches between placeholder scroll views and a
  /// paginated [ListView] so the layout stays consistent across data states.
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
          scrollCacheExtent: ScrollCacheExtent.viewport(widget.cacheExtent),
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
