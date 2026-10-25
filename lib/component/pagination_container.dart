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
  ///
  /// For a fixed, already-complete list that needs no pagination wiring, pass
  /// [items] and omit [paginate] and [stream]. The list is then rendered as
  /// [embedded]: it sizes itself to its content and lets the enclosing
  /// scrollable own every drag, so it can sit directly inside a chat list.
  const PaginationContainer({
    super.key,
    this.paginate,
    required this.itemBuilder,
    this.items,
    this.primary = false,
    this.reverse = false,
    this.padding = EdgeInsets.zero,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 2,
    this.empty,
    this.loading,
    this.end,
    this.stream,
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

  /// Fixed list of items to render without requesting any further page.
  ///
  /// When set, the container renders exactly this snapshot: [stream] publishes
  /// nothing, [paginate] is never awaited, and the terminal footer appears as
  /// soon as the last item is built. Defaults to `null`, which keeps the
  /// paginated behavior.
  final List<dynamic>? items;

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
  /// See [RevealController]. Only the item being revealed is wrapped in a keyed
  /// subtree; without a controller the item tree is unchanged.
  final RevealController? controller;

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
  /// state to reset or replace the rendered data at any time. Optional when
  /// [items] is given, in which case the list never changes.
  final Stream<dynamic>? stream;

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
  /// the terminal footer. Optional when [items] is given.
  final Future<dynamic> Function()? paginate;

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
/// Pass one instance to [PaginationContainer.controller] and call
/// [RevealController.reveal] with an item index or a predicate
/// `bool Function(dynamic item)`. Calls return `false` while no container is
/// attached, or when the target cannot be built.
class _PaginationRevealHandler implements RevealHandler {
  _PaginationRevealHandler(this._state);

  final _PaginationContainerState _state;

  @override
  Future<bool> revealTarget(Object target, double alignment) {
    if (target is int) return _state._revealIndex(target, alignment, 5);
    if (target is bool Function(dynamic)) {
      return _state._revealWhere(target, alignment, 5);
    }
    return Future.value(false);
  }
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

  /// The single key that locates the item currently being revealed.
  ///
  /// Only one item is ever wrapped in [_revealKey], so a long list never pays
  /// for a key per built row. The slot is cleared as soon as the reveal ends.
  final GlobalKey _revealKey = GlobalKey();

  /// What [_revealKey] is currently addressing.
  ///
  /// Either an `int` index into [data] or a `bool Function(dynamic item)`
  /// predicate. Both are re-resolved against the live [data] on every build, so
  /// a list that is prepended to or reordered still reveals the same item.
  Object? _revealTarget;

  /// The index [_revealKey] is currently attached to, or `null` when the key is
  /// not in the tree. Tracked separately from [_revealTarget] because a
  /// predicate slot has no index of its own.
  int? _revealKeyIndex;

  /// Bridges [RevealController.reveal] calls onto this container's own logic.
  late final _PaginationRevealHandler _revealHandler = _PaginationRevealHandler(
    this,
  );

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(_revealHandler);

    error = null;
    data = widget.items ?? widget.initialData ?? [];
    isBottom = false;
    // A fixed [PaginationContainer.items] snapshot is already complete, so the
    // container reports the end immediately instead of showing a loading
    // placeholder or awaiting a page that will never arrive.
    end = widget.items != null;
    loading = widget.items == null && widget.initialData == null;
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

    final subscription = widget.stream?.listen((event) async {
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
    subscription?.onError((e) {
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
    if (widget.paginate == null) {
      end = true;
      if (mounted) setState(() {});
      return;
    }
    loading = true;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      error = null;
      final paginationData = await widget.paginate!();
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

  /// Implements [RevealController.reveal] for a predicate target.
  Future<bool> _revealWhere(
    bool Function(dynamic item) test,
    double alignment,
    int maxPages,
  ) async {
    int find() => data.indexWhere(test);
    await _loadUntil(() => find() >= 0, maxPages);
    final index = find();
    if (index < 0) {
      _clearRevealSlot();
      return false;
    }
    // The predicate, not the resolved index, stays in the reveal slot so pages
    // arriving mid-reveal (and any reorder they cause) keep addressing the same
    // item.
    return _revealIndex(index, alignment, 0, slot: test);
  }

  /// Implements [RevealController.reveal] for an index target.
  Future<bool> _revealIndex(
    int index,
    double alignment,
    int maxPages, {
    Object? slot,
  }) async {
    if (index < 0) return false;
    _revealTarget = slot ?? index;
    await _loadUntil(() => index < data.length, maxPages);
    // Positional targets are re-resolved on every pass: a page that prepends
    // (the newest-first case) shifts the item down, so holding on to [index]
    // would walk toward — and finally reveal — whatever now sits at it.
    int? resolve() {
      if (slot == null) return index < data.length ? index : null;
      final found = data.indexWhere(slot as bool Function(dynamic));
      return found < 0 ? null : found;
    }

    var resolved = resolve();
    if (!mounted || resolved == null) {
      _clearRevealSlot();
      return false;
    }
    // Fragment the build: the slot may be addressing an item that is not the
    // one currently wrapped in [_revealKey] (a reordered or prepended list), so
    // the key is re-published and the walk re-run until the target itself is
    // the wrapped item.
    if (!_isTargetBuilt(resolved)) {
      _setRevealSlot();
      // Drives the lazy list toward the item until it is built. The estimate
      // uses the scrollable extent, then walks by viewport pages toward the
      // nearest built neighbour when the estimate undershoots.
      for (
        var attempt = 0;
        attempt < 24 && !_isTargetBuilt(resolved!);
        attempt++
      ) {
        if (!mounted) break;
        resolved = resolve();
        if (resolved == null) break;
        if (_controller.hasClients &&
            _controller.position.hasContentDimensions) {
          final position = _controller.position;
          final total = data.length;
          final extent = position.maxScrollExtent + position.viewportDimension;
          var target = attempt == 0
              ? extent * resolved / total
              : position.pixels +
                    _directionToward(resolved) *
                        position.viewportDimension *
                        0.8;
          target = target.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          if ((target - position.pixels).abs() > 1) _controller.jumpTo(target);
        }
        await _frames();
      }
      resolved = resolve();
    }
    final context = resolved != null && _isTargetBuilt(resolved)
        ? _revealKey.currentContext
        : null;
    if (context == null || !context.mounted) {
      _clearRevealSlot();
      return false;
    }
    try {
      return await ScrollReveal.reveal(context, alignment: alignment);
    } finally {
      _clearRevealSlot();
    }
  }

  /// Whether [_revealKey] currently wraps the item at [index].
  bool _isTargetBuilt(int index) => _revealKeyIndex == index;

  /// Publishes the reveal slot so the item is wrapped in [_revealKey].
  void _setRevealSlot() {
    if (!mounted) return;
    setState(() {});
  }

  /// Clears the reveal slot so the item stops being wrapped in a key.
  void _clearRevealSlot() {
    if (_revealTarget == null) return;
    _revealTarget = null;
    _revealKeyIndex = null;
    _setRevealSlot();
  }

  /// Whether [_revealKey] should wrap the item at [index].
  bool _isRevealTarget(int index) {
    final target = _revealTarget;
    if (target == null) return false;
    if (target is int) return target == index;
    if (target is bool Function(dynamic)) return target(data[index]);
    return false;
  }

  /// The lowest and highest indices among the currently built list children.
  ///
  /// A lazily built [ListView] only holds the rows near the viewport, so the
  /// range decides which way the reveal walk has to travel. Returns `null`
  /// while the sliver has no children.
  (int, int)? _builtIndexBounds() {
    if (!_controller.hasClients) return null;
    final object = _controller.position.context.storageContext
        .findRenderObject();
    if (object is! RenderSliverMultiBoxAdaptor) return null;
    int? lowest;
    int? highest;
    for (RenderBox? child = object.firstChild; child != null;) {
      final parentData = child.parentData;
      if (parentData is! SliverMultiBoxAdaptorParentData) break;
      final index = parentData.index;
      if (index != null) {
        if (lowest == null || index < lowest) lowest = index;
        if (highest == null || index > highest) highest = index;
      }
      child = parentData.nextSibling;
    }
    if (lowest == null || highest == null) return null;
    return (lowest, highest);
  }

  /// Returns `-1` when the built items sit before [index] and `1` when after.
  double _directionToward(int index) {
    final bounds = _builtIndexBounds();
    if (bounds == null) return 1;
    return index < bounds.$1 ? -1 : 1;
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
    widget.controller?.detach(_revealHandler);
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
      oldWidget.controller?.detach(_revealHandler);
      widget.controller?.attach(_revealHandler);
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
      // Reset the derived key-index cache; the item builder re-populates it only
      // if the wrapped item is actually built this frame, so an off-screen
      // target never reads as "built".
      var revealed = false;
      _revealKeyIndex = null;
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
            // Exactly one item is wrapped in the reveal key at any time, so a
            // long list never allocates a key per built row and a predicate
            // target can never collide with a second match.
            if (revealed || !_isRevealTarget(index)) return item;
            revealed = true;
            _revealKeyIndex = index;
            return KeyedSubtree(key: _revealKey, child: item);
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
