import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Scrolls a widget into view and keeps it there while the layout settles.
///
/// [Scrollable.ensureVisible] runs once, so it misses targets whose
/// surroundings keep changing after the call (async content growing above the
/// target, images loading, expanding tiles). [ScrollReveal.reveal] repeats the
/// reveal for a short settle window, works through nested scrollables, backs
/// off as soon as the user scrolls, and respects the platform reduce-motion
/// setting. It is stateless and has no effect unless it is called.
///
/// Only one reveal runs at a time: starting a new one cancels the reveal that
/// is already in flight, which then returns `false`.
class ScrollReveal {
  const ScrollReveal._();

  /// Pixel deviation from the requested alignment above which the target counts
  /// as drifted and is scrolled back.
  ///
  /// A tight threshold makes the loop chase sub-pixel changes, image loads and
  /// text reflow; too loose leaves the target visibly off. 24 logical pixels
  /// stays well inside a line of text, so a target parked within it still reads
  /// as revealed and the loop stops forcing frames on a settled page.
  static const double _realignDrift = 24.0;

  /// Animation used to correct a target that has drifted far, when animations
  /// are enabled. A short glide reads as a correction rather than a jump.
  static const Duration _realignDuration = Duration(milliseconds: 120);

  /// Longest a reveal waits for a rendered frame before re-reading the target.
  ///
  /// The loop never forces frames: a page that is not changing produces none,
  /// and the reveal falls back to polling the last rendered layout on this
  /// interval. Anything that moves schedules its own frame, so a change is
  /// still observed, but an idle page costs no frames at all.
  static const Duration _frameTimeout = Duration(milliseconds: 100);

  /// Sequence number handed to each [reveal] call.
  static int _tokenSequence = 0;

  /// Token of the reveal currently in flight, or `null` when none is running.
  static int? _activeToken;

  /// Reveals [target] in every enclosing [Scrollable].
  ///
  /// The first scroll animates over [duration] with [curve], or jumps when
  /// [MediaQuery.disableAnimationsOf] is true. Afterwards the target is
  /// re-checked once per rendered frame; whenever it has drifted more than
  /// [_realignDrift] from [alignment] it is scrolled back, with a short
  /// animation unless animations are disabled. The loop ends when the target
  /// has stayed in place for [quiet], when [settle] has elapsed, when the
  /// target is unmounted, when the user scrolls, or when another reveal
  /// supersedes this one.
  ///
  /// [alignment] follows [Scrollable.ensureVisible]: `0` places the target at
  /// the leading edge of the viewport and `1` at the trailing edge.
  ///
  /// Returns `true` when the target ended aligned in the viewport, and
  /// `false` when it was unmounted, there is no enclosing [Scrollable], the
  /// user took over, or a newer reveal cancelled this one.
  static Future<bool> reveal(
    BuildContext target, {
    double alignment = 0.1,
    Duration settle = const Duration(milliseconds: 1500),
    Duration quiet = const Duration(milliseconds: 500),
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
  }) async {
    if (!target.mounted || Scrollable.maybeOf(target) == null) return false;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(target) ?? false;
    final positions = _ancestorPositions(target);
    final token = ++_tokenSequence;
    _activeToken = token;
    var userScrolled = false;
    void onScroll() {
      for (final position in positions) {
        if (position.userScrollDirection != ScrollDirection.idle) {
          userScrolled = true;
        }
      }
    }

    for (final position in positions) {
      position.addListener(onScroll);
    }
    try {
      await Scrollable.ensureVisible(
        target,
        alignment: alignment,
        duration: reduceMotion ? Duration.zero : duration,
        curve: curve,
      );
      if (_activeToken != token || userScrolled) return false;
      var elapsed = Duration.zero;
      var stableSince = Duration.zero;
      var idleFor = Duration.zero;
      Duration? last;
      // A frame is only delivered when something on screen changed, so a
      // missing frame is idleness: the page is not moving and the target has
      // settled. The loop waits out [quiet] of such idleness and then stops,
      // instead of forcing frames for the whole [settle] window on a static
      // page. Anything that moves schedules its own frame and is still seen.
      while (elapsed < settle && elapsed - stableSince < quiet) {
        final stamp = await _nextFrame(_frameTimeout);
        if (_activeToken != token) return false;
        if (stamp == null) {
          idleFor += _frameTimeout;
          elapsed += _frameTimeout;
          if (idleFor >= quiet) break;
          continue;
        }
        idleFor = Duration.zero;
        elapsed += stamp - (last ??= stamp);
        last = stamp;
        if (userScrolled) return false;
        if (!target.mounted) return false;
        if (!_isAligned(target, alignment)) {
          stableSince = elapsed;
          await _realign(target, alignment, reduceMotion: reduceMotion);
        }
      }
      return target.mounted && _isAligned(target, alignment);
    } finally {
      if (_activeToken == token) _activeToken = null;
      for (final position in positions) {
        position.removeListener(onScroll);
      }
    }
  }

  /// Scrolls [target] back to [alignment] after it has drifted.
  ///
  /// Drift inside [_realignDrift] is ignored: correcting it would move the
  /// viewport for changes the user cannot see. Larger drift glides over
  /// [_realignDuration], or jumps when [reduceMotion] is set.
  static Future<void> _realign(
    BuildContext target,
    double alignment, {
    required bool reduceMotion,
  }) async {
    await Scrollable.ensureVisible(
      target,
      alignment: alignment,
      duration: reduceMotion ? Duration.zero : _realignDuration,
      curve: Curves.easeOut,
    );
  }

  /// Completes with the timestamp of the next rendered frame, or with `null`
  /// when no frame is rendered within [timeout].
  ///
  /// Waiting on a post-frame callback, rather than forcing frames with
  /// [SchedulerBinding.scheduleFrame], keeps a page that is no longer changing
  /// from being driven frame by frame for the whole settle window. Anything
  /// that changes layout schedules its own frame, so a real change is still
  /// seen; a page with nothing left to render reports `null`, which lets the
  /// loop conclude that the target has settled without spending a frame on it.
  static Future<Duration?> _nextFrame(Duration timeout) {
    final completer = Completer<Duration?>();
    late final Timer timer;
    timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(timeStamp);
    }, debugLabel: 'ScrollReveal.frame');
    return completer.future;
  }

  /// Collects the [ScrollPosition] of every [Scrollable] enclosing [target].
  static List<ScrollPosition> _ancestorPositions(BuildContext target) {
    final positions = <ScrollPosition>[];
    var scrollable = Scrollable.maybeOf(target);
    while (scrollable != null) {
      positions.add(scrollable.position);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    return positions;
  }

  /// Whether every enclosing scrollable already shows [target] at [alignment].
  ///
  /// Mirrors the walk performed by [Scrollable.ensureVisible] so both agree on
  /// what "revealed" means, including positions clamped at a scroll extent.
  /// For an enclosing scrollable the rect handed to
  /// [RenderAbstractViewport.getOffsetToReveal] is [ScrollPosition.ensureVisible]'s
  /// own expression — the target's bounds clipped to the intermediate object's
  /// bounds, mapped into the intermediate's space. Clipping first matters: the
  /// target is often larger than the scrollable it sits in, and the unclipped
  /// bounds would ask for an offset the position cannot reach, so the loop
  /// would never converge and the reveal would report failure for a target
  /// that is in fact aligned.
  static bool _isAligned(BuildContext target, double alignment) {
    var context = target;
    var scrollable = Scrollable.maybeOf(context);
    RenderObject? targetObject;
    while (scrollable != null) {
      final object = context.findRenderObject();
      final position = scrollable.position;
      if (object == null || !object.attached || !position.hasPixels) {
        return true;
      }
      final viewport = RenderAbstractViewport.maybeOf(object);
      if (viewport == null || !position.hasContentDimensions) return true;
      final targetRect = targetObject == null || identical(targetObject, object)
          ? null
          : MatrixUtils.transformRect(
              targetObject.getTransformTo(object),
              object.paintBounds.intersect(targetObject.paintBounds),
            );
      final desired = viewport
          .getOffsetToReveal(
            object,
            alignment,
            rect: targetRect,
            axis: position.axis,
          )
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((desired - position.pixels).abs() > _realignDrift) return false;
      targetObject ??= object;
      context = scrollable.context;
      scrollable = Scrollable.maybeOf(context);
    }
    return true;
  }
}

/// Reveals a target inside a widget that owns a scrollable.
///
/// A widget attaches itself to one controller instance, which is then passed to
/// its `controller:` parameter. The controller exposes a single entry point —
/// [reveal] — and each widget maps the target onto its own layout:
///
/// * `PaginationContainer`: an `int` index, or a predicate
///   `bool Function(dynamic item)` matched against the loaded items.
/// * `StepperExtended`: a step `int` index.
/// * `ExpansionTable`: a `TableRowData` or a row `int` index, with an optional
///   `column` (`int`) selected through [RevealTarget.column].
///
/// Calling [reveal] while no widget is attached returns `false`.
class RevealController {
  /// The widget currently driven by this controller.
  RevealHandler? _handler;

  /// Keys that locate built targets, keyed by identity.
  ///
  /// Shared by a widget and every nested widget it builds, so a single
  /// controller keeps exactly one key per revealed target.
  final Map<Object, GlobalKey> _targetKeys = Map.identity();

  /// Reveals [target] inside the attached widget.
  ///
  /// Returns `true` when the target ended in view, and `false` when no widget
  /// is attached, the target is not recognized, the target is missing, or a
  /// newer reveal cancelled this one. [alignment] follows
  /// [Scrollable.ensureVisible]: `0.0` parks the target at the leading edge and
  /// `1.0` at the trailing edge.
  Future<bool> reveal(Object target, {double alignment = 0.1}) {
    final handler = _handler;
    if (handler == null) return Future.value(false);
    return handler.revealTarget(target, alignment);
  }

  /// Binds [handler] to this controller.
  ///
  /// Called by the widget that owns [handler] from `initState` and from
  /// `didUpdateWidget` when the controller changes. Not part of the public API.
  void attach(RevealHandler handler) => _handler = handler;

  /// Unbinds [handler] when it is still the attached one.
  ///
  /// Called from `dispose`. A widget that was already replaced by a newer
  /// attachment leaves the newer handler untouched.
  void detach(RevealHandler handler) {
    if (!identical(_handler, handler)) return;
    _handler = null;
    _targetKeys.clear();
  }

  /// Returns the stable key that locates [target] in the widget tree.
  ///
  /// Widgets that wrap their items in a keyed subtree use this to find the
  /// target again on a later build. Not part of the public API.
  GlobalKey keyFor(Object target) =>
      _targetKeys.putIfAbsent(target, GlobalKey.new);
}

/// Contract implemented by widgets that accept a [RevealController].
///
/// This is an implementation detail of [`PaginationContainer`],
/// [`StepperExtended`] and [`ExpansionTable`]; consumers call
/// [RevealController.reveal] instead of implementing it.
abstract class RevealHandler {
  /// Reveals [target], mapping it onto the widget's own layout.
  ///
  /// [alignment] follows [Scrollable.ensureVisible]. Returns `true` when the
  /// target ended in view.
  Future<bool> revealTarget(Object target, double alignment);
}

/// Refines a [RevealController.reveal] target with an extra qualifier.
///
/// Widgets accept their natural target directly — an `int` index, a predicate,
/// or a `TableRowData` — so this is only needed for the richer cases:
///
/// ```dart
/// // ExpansionTable: reveal row 3 and bring column 2 into view too.
/// controller.reveal(RevealTarget(target: 3, column: 2));
///
/// // ExpansionTable: pan the horizontal axis only, leaving the row alone.
/// controller.reveal(RevealTarget(column: 2));
///
/// // StepperExtended: reveal step 7 and park on a control inside it.
/// controller.reveal(RevealTarget(target: 7, within: contentKey));
/// ```
class RevealTarget {
  /// Wraps an optional target, optionally qualifying it with [column] or
  /// [within].
  ///
  /// Omitting [target] is only meaningful for `ExpansionTable`, where a
  /// column-only reveal pans the horizontal axis without touching the vertical
  /// position.
  const RevealTarget({this.target, this.column, this.within});

  /// The qualified target: an `int` index, a predicate, or a `TableRowData`.
  ///
  /// `null` leaves the widget to act on the qualifier alone.
  final Object? target;

  /// Zero-based column index to reveal as well, or `null` to leave it alone.
  ///
  /// Only `ExpansionTable` reads this.
  final int? column;

  /// Widget inside the step to reveal instead of the step itself.
  ///
  /// Only `StepperExtended` reads this.
  final GlobalKey? within;
}
