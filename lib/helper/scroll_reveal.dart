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
class ScrollReveal {
  const ScrollReveal._();

  /// Pixel tolerance under which a scroll position counts as aligned.
  static const double _tolerance = 1.0;

  /// Reveals [target] in every enclosing [Scrollable].
  ///
  /// The first scroll animates over [duration] with [curve], or jumps when
  /// [MediaQuery.disableAnimationsOf] is true. Afterwards the target is
  /// re-checked once per frame; whenever it has drifted away from
  /// [alignment] it is scrolled back without animation. The loop ends when the
  /// target has stayed in place for [quiet], when [settle] has elapsed, when
  /// the target is unmounted, or when the user scrolls.
  ///
  /// [alignment] follows [Scrollable.ensureVisible]: `0` places the target at
  /// the leading edge of the viewport and `1` at the trailing edge.
  ///
  /// Returns `true` when the target ended aligned in the viewport, and
  /// `false` when it was unmounted, there is no enclosing [Scrollable], or the
  /// user took over.
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
      var elapsed = Duration.zero;
      var stableSince = Duration.zero;
      Duration? last;
      while (elapsed < settle && elapsed - stableSince < quiet) {
        final stamp = await _nextFrame();
        last ??= stamp;
        elapsed += stamp - last;
        last = stamp;
        if (userScrolled) return false;
        if (!target.mounted) return false;
        if (!_isAligned(target, alignment)) {
          stableSince = elapsed;
          await Scrollable.ensureVisible(
            target,
            alignment: alignment,
            duration: Duration.zero,
          );
        }
      }
      return target.mounted && _isAligned(target, alignment);
    } finally {
      for (final position in positions) {
        position.removeListener(onScroll);
      }
    }
  }

  /// Completes with the timestamp of the next rendered frame.
  static Future<Duration> _nextFrame() {
    final completer = Completer<Duration>();
    SchedulerBinding.instance.addPostFrameCallback(completer.complete);
    SchedulerBinding.instance.scheduleFrame();
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
  /// Outermost scrollables are measured against the original target's bounds
  /// rather than the intermediate viewport's, which is what makes a target
  /// inside a nested scrollable count as aligned.
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
      if ((desired - position.pixels).abs() > _tolerance) return false;
      targetObject ??= object;
      context = scrollable.context;
      scrollable = Scrollable.maybeOf(context);
    }
    return true;
  }
}
