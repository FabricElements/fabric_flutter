import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/density_spacing.dart';
import '../helper/log_color.dart';
import '../helper/scroll_reveal.dart';
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
    this.embedded = false,
    this.controller,
  });

  /// Creates an embeddable list that renders a fixed, JSON-friendly [items]
  /// snapshot without any pagination wiring.
  ///
  /// The list is [embedded], so it sizes itself to its content and lets the
  /// enclosing scrollable own every drag. No stream is required; the list is
  /// seeded with [items] and never requests another page.
  const PaginationContainer.items({
    super.key,
    required List<dynamic> items,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.empty,
    this.top,
    this.bottom,
    this.onError,
    this.controller,
  }) : paginate = _noMorePages,
       stream = const Stream<dynamic>.empty(),
       initialData = items,
       primary = false,
       reverse = false,
       scrollDirection = Axis.vertical,
       cacheExtent = 2,
       loading = null,
       end = null,
       clipBehavior = Clip.hardEdge,
       shrinkWrap = true,
       initialScrollOffset = 0.0,
       onScrollOffsetChanged = null,
       embedded = true;

  /// Reports that no further page exists.
  static Future<dynamic> _noMorePages() async => null;

  /// Renders the list inside a parent scrollable instead of owning scrolling.
  ///
  /// When `true` the list sizes itself to its items ([shrinkWrap] behavior),
  /// ignores [primary], never captures drag gestures, and replaces the
  /// scroll-edge pagination trigger with the explicit "load more" button.
  /// Use it inside chat lists or any other vertical scroll view. Defaults to
  /// `false`, which keeps the existing behavior.
  final bool embedded;

  /// Optional handle used to reveal items by index or predicate.
  ///
  /// See [PaginationContainerController]. Attaching a controller wraps each
  /// item in a keyed subtree; without one the item tree is unchanged.
  final PaginationContainerController? controller;

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

/// Reveals items of a [PaginationContainer] that may not be built yet.
///
/// Pass one instance to [PaginationContainer.controller]. Calls return `false`
/// while no container is attached.
class PaginationContainerController {
  _PaginationContainerState? _state;

  /// The items currently loaded, or an empty list when detached.
  List<dynamic> get items => _state?.data ?? const [];

  /// Scrolls to the item at [index], building it first if needed.
  ///
  /// When [index] is beyond the loaded items, further pages are requested, at
  /// most [maxPages] times. The scroll then moves toward the estimated offset
  /// until the item is built and finally hands over to
  /// [ScrollReveal.reveal] with [alignment]. Returns `true` when the item
  /// ended in view.
  Future<bool> revealIndex(
    int index, {
    double alignment = 0.1,
    int maxPages = 5,
  }) async => await _state?._revealIndex(index, alignment, maxPages) ?? false;

  /// Scrolls to the first loaded item for which [test] returns `true`.
  ///
  /// Loads up to [maxPages] further pages when no loaded item matches. Returns
  /// `false` when nothing matches within that bound.
  Future<bool> revealWhere(
    bool Function(dynamic item) test, {
    double alignment = 0.1,
    int maxPages = 5,
  }) async => await _state?._revealWhere(test, alignment, maxPages) ?? false;
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

  /// Tracks the current page number for the live-region announcement.
  ///
  /// Incremented only when [_requestNextPage] actually loads a non-empty page,
  /// so the announcement fires once per real page transition instead of on
  /// every rebuild.
  int _pageNumber = 1;

  /// Initializes pagination flags and subscribes to scroll and stream updates.
  ///
  /// The method seeds the list from [PaginationContainer.initialData], restores
  /// scroll offset, and wires listeners that update loading, error, and end
  /// state as new pages or streamed snapshots arrive.
  /// Tracks the [PaginationContainer.stream] subscription so it can be
  /// cancelled when the widget is disposed.
  StreamSubscription<dynamic>? _streamSubscription;

  /// Keys that locate built items for [PaginationContainerController].
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;

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
      await _requestNextPage();
    });

    final subscription = widget.stream.listen((event) async {
      loading = true;
      if (mounted) setState(() {});
      final eventData = event != null ? event as List<dynamic> : null;
      data = eventData ?? widget.initialData ?? [];
      end = false;
      // A new stream snapshot replaces the whole list (e.g. a filter change),
      // so page counting restarts here rather than being announced as a page
      // transition.
      _pageNumber = 1;
      loading = false;
      if (mounted) setState(() {});
    });
    subscription.onError((e) {
      error = e.toString();
      _reportError(error!);
      loading = false;
      end = false;
      if (mounted) setState(() {});
    });
    _streamSubscription = subscription;
  }

  /// Requests the next page from [PaginationContainer.paginate].
  ///
  /// Shared by the scroll-to-edge listener and, when
  /// [MediaQuery.accessibleNavigationOf] reports a screen reader is active,
  /// the explicit "load more" button rendered in the footer — reaching the
  /// exact scroll edge is unreliable for assistive-technology users, so they
  /// get a directly actionable control instead of relying on auto-loading.
  Future<void> _requestNextPage() async {
    if (end) return;
    if (loading) return;
    loading = true;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      error = null;
      final paginationData = await widget.paginate();
      end = paginationData == null || paginationData.isEmpty;
      if (!end) {
        _pageNumber++;
        _announcePageChange();
      }
    } catch (e) {
      error = e.toString();
      _reportError(error!);
    }
    await Future.delayed(const Duration(milliseconds: 300));
    loading = false;
    if (mounted) setState(() {});
  }

  /// Waits for [frames] rendered frames.
  Future<void> _frames([int frames = 1]) async {
    for (var i = 0; i < frames; i++) {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
      WidgetsBinding.instance.scheduleFrame();
      await completer.future;
    }
  }

  /// Requests pages until [done] holds, the list ends, or [maxPages] is hit.
  Future<void> _loadUntil(bool Function() done, int maxPages) async {
    var pages = 0;
    while (mounted && !done() && !end && pages < maxPages) {
      if (loading) {
        await _frames(2);
        continue;
      }
      pages++;
      await _requestNextPage();
      await _frames(2);
    }
  }

  /// Implements [PaginationContainerController.revealWhere].
  Future<bool> _revealWhere(
    bool Function(dynamic item) test,
    double alignment,
    int maxPages,
  ) async {
    int find() => data.indexWhere(test);
    await _loadUntil(() => find() >= 0, maxPages);
    final index = find();
    if (index < 0) return false;
    return _revealIndex(index, alignment, 0);
  }

  /// Implements [PaginationContainerController.revealIndex].
  Future<bool> _revealIndex(int index, double alignment, int maxPages) async {
    if (index < 0) return false;
    await _loadUntil(() => index < data.length, maxPages);
    if (!mounted || index >= data.length) return false;
    final key = _itemKeys.putIfAbsent(index, GlobalKey.new);
    // Drives the lazy list toward the item until it is built. The estimate
    // uses the scrollable extent, then walks by viewport pages toward the
    // nearest built neighbour when the estimate undershoots.
    for (
      var attempt = 0;
      attempt < 24 && key.currentContext == null;
      attempt++
    ) {
      if (!mounted) return false;
      if (_controller.hasClients && _controller.position.hasContentDimensions) {
        final position = _controller.position;
        final total = data.length;
        final extent = position.maxScrollExtent + position.viewportDimension;
        var target = attempt == 0
            ? extent * index / total
            : position.pixels +
                  _directionToward(index) * position.viewportDimension * 0.8;
        target = target.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((target - position.pixels).abs() > 1) _controller.jumpTo(target);
      }
      await _frames();
    }
    final context = key.currentContext;
    if (context == null || !context.mounted) return false;
    return ScrollReveal.reveal(context, alignment: alignment);
  }

  /// Returns `1` when the built items sit before [index] and `-1` when after.
  double _directionToward(int index) {
    for (final entry in _itemKeys.entries) {
      if (entry.value.currentContext != null) {
        return entry.key < index ? 1 : -1;
      }
    }
    return 1;
  }

  /// Announces the new page number to assistive technology.
  ///
  /// Called only from [_requestNextPage] right after a real page transition
  /// succeeds — never from [build] — so the announcement never fires on a
  /// plain rebuild (e.g. scrolling, a `setState` for `loading`, or resizing).
  void _announcePageChange() {
    if (!mounted) return;
    final locales = AppLocalizations.of(context);
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${locales.get('label--page')} $_pageNumber',
      Directionality.of(context),
    );
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
    if (widget.controller?._state == this) widget.controller?._state = null;
    _controller.dispose();
    // `drain()` attaches a *second* listener instead of releasing the first one,
    // so the original subscription kept firing after dispose. Cancel it.
    _streamSubscription?.cancel();
    _streamSubscription = null;
    super.dispose();
  }

  /// Builds the loading, empty, populated, or error-aware pagination view.
  ///
  /// The returned widget switches between placeholder scroll views and a
  /// paginated [ListView] so the layout stays consistent across data states.
  @override
  void didUpdateWidget(covariant PaginationContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final density = DensitySpacing.of(context);
    // Reaching the exact scroll edge that triggers auto-pagination is
    // unreliable for screen-reader users, so an explicit "load more" control
    // is offered instead of relying on scroll position when a screen reader
    // is active.
    final accessibleNavigation =
        MediaQuery.accessibleNavigationOf(context) || widget.embedded;
    final lockedPhysics = widget.embedded
        ? const NeverScrollableScrollPhysics()
        : (widget.shrinkWrap ? null : const ClampingScrollPhysics());
    int total = data.length;
    final widgetEmpty =
        widget.empty ??
        Card(
          margin: density.all(16, min: 8),
          child: ListTile(
            contentPadding: density.all(16, min: 8),
            leading: Icon(Icons.info),
            title: Text(locales.get('label--nothing-here-yet')),
          ),
        );
    final widgetLoading =
        widget.loading ??
        Padding(
          padding: density.all(16, min: 8),
          child: LinearProgressIndicator(),
        );
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
        physics: lockedPhysics,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: density.gap(16),
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
        physics: lockedPhysics,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: density.gap(16),
          children: [
            ?widget.top,
            ContentContainer(padding: widget.padding, child: widgetEmpty),
            ?widget.bottom,
          ],
        ),
      );
    } else {
      int totalCount = total;
      if (loading ||
          error != null ||
          end ||
          isBottom ||
          (accessibleNavigation && !end)) {
        totalCount++;
      }
      final list = ListView.builder(
        key: const PageStorageKey('pagination-container-scroll'),
        restorationId: 'pagination-container',
        physics: lockedPhysics,
        clipBehavior: widget.clipBehavior,
        primary: widget.embedded ? false : widget.primary,
        scrollCacheExtent: ScrollCacheExtent.viewport(widget.cacheExtent),
        controller: _controller,
        itemCount: totalCount,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap || widget.embedded,
        itemBuilder: (BuildContext context, int index) {
          if (index < total) {
            final item = _buildItem(context, index, total, density);
            if (widget.controller == null) return item;
            return KeyedSubtree(
              key: _itemKeys.putIfAbsent(index, GlobalKey.new),
              child: item,
            );
          }
          Widget footer = Semantics(
            label: locales.get('label--nothing-here-yet'),
            child: widgetEnd,
          );
          if (error != null) {
            footer = Semantics(
              liveRegion: true,
              child: Card(
                margin: density.all(16, min: 8),
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  contentPadding: density.all(16, min: 8),
                  leading: Icon(Icons.error),
                  title: Text(error!),
                  textColor: theme.colorScheme.onErrorContainer,
                  iconColor: theme.colorScheme.onErrorContainer,
                ),
              ),
            );
          } else if (loading) {
            footer = Semantics(
              liveRegion: true,
              label: locales.get('label--loading'),
              child: widgetLoading,
            );
          } else if (!end && accessibleNavigation) {
            // Explicit, focusable alternative to the scroll-edge trigger so
            // assistive-technology users can reliably load more results.
            footer = Center(
              child: Padding(
                padding: density.all(16, min: 8),
                child: OutlinedButton.icon(
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size(48, 48)),
                  ),
                  onPressed: _requestNextPage,
                  icon: const Icon(Icons.expand_more),
                  label: Text(locales.get('label--load-more').toUpperCase()),
                ),
              ),
            );
          }
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: kToolbarHeight * 2),
            child: ContentContainer(child: footer),
          );
        },
        reverse: widget.reverse,
        scrollDirection: widget.scrollDirection,
      );
      content = widget.embedded
          ? list
          : Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              controller: _controller,
              child: list,
            );
    }

    return content;
  }

  /// Builds the item at [index], adding [PaginationContainer.top] before the
  /// first and [PaginationContainer.bottom] before the last entry.
  Widget _buildItem(
    BuildContext context,
    int index,
    int total,
    DensitySpacing density,
  ) {
    final child = widget.itemBuilder(context, index, data[index]);
    if (index == 0 && widget.top != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: density.gap(16),
        children: [widget.top!, child],
      );
    } else if (index == (total - 1) && widget.bottom != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: density.gap(16),
        children: [widget.bottom!, child],
      );
    }
    return child;
  }
}
