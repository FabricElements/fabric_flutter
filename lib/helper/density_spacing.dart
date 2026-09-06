import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Derives density-aware spacing values from `Theme.of(context).visualDensity`
/// so hardcoded paddings, gaps, and fixed heights scale with the user's
/// chosen visual density instead of staying fixed.
///
/// Material widgets already grow or shrink automatically with
/// [VisualDensity] because they read it from the ambient [ThemeData]
/// internally. Custom layouts that hardcode a spacing or size value — a
/// `Padding`, a `SizedBox` gap between buttons, a fixed-height header — do
/// not get that adjustment for free. `DensitySpacing` closes that gap by
/// reusing [VisualDensity.baseSizeAdjustment], the very same offset Material
/// widgets use internally, rather than reinventing density math.
///
/// Every method accepts a `min` floor so a value never collapses below a
/// usable or accessible size when [visualDensity] is very compact (density
/// adjustments can be negative).
///
/// Typical usage inside a `build` method:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final density = DensitySpacing.of(context);
///   return Padding(
///     padding: density.all(16, min: 8),
///     child: Row(
///       children: [
///         const Icon(Icons.star),
///         SizedBox(width: density.gap(8)),
///         const Text('Favorite'),
///       ],
///     ),
///   );
/// }
/// ```
class DensitySpacing {
  /// Creates a [DensitySpacing] that scales values using [visualDensity].
  ///
  /// Prefer [DensitySpacing.of] when a [BuildContext] is available so the
  /// density always matches the ambient [Theme].
  const DensitySpacing(this.visualDensity);

  /// Builds a [DensitySpacing] from the ambient [Theme]'s
  /// [ThemeData.visualDensity].
  ///
  /// This is the usual entry point: `DensitySpacing.of(context)` inside a
  /// `build` method always reflects the density currently in effect for
  /// [context], including changes made at runtime (e.g. a settings screen
  /// that lets the user pick a density).
  factory DensitySpacing.of(BuildContext context) {
    return DensitySpacing(Theme.of(context).visualDensity);
  }

  /// The visual density this instance scales values by.
  final VisualDensity visualDensity;

  /// Scales a horizontal spacing [value] by half of
  /// [VisualDensity.baseSizeAdjustment]'s horizontal component.
  ///
  /// Halving mirrors how [EdgeInsets.symmetric] and similar Material spacing
  /// APIs apply density: the adjustment represents the total change across
  /// both sides of an axis, so half of it applies to a single side. The
  /// result never goes below [min].
  double horizontal(double value, {double min = 0}) {
    return math.max(min, value + visualDensity.baseSizeAdjustment.dx / 2);
  }

  /// Scales a vertical spacing [value] by half of
  /// [VisualDensity.baseSizeAdjustment]'s vertical component.
  ///
  /// See [horizontal] for why the adjustment is halved. The result never
  /// goes below [min].
  double vertical(double value, {double min = 0}) {
    return math.max(min, value + visualDensity.baseSizeAdjustment.dy / 2);
  }

  /// Scales a directionless gap [value] (e.g. the space between two items in
  /// a `Row`, `Column`, or `Wrap`) by the average of
  /// [VisualDensity.baseSizeAdjustment]'s horizontal and vertical
  /// components.
  ///
  /// Averaging keeps a single gap value reasonable when
  /// [VisualDensity.horizontal] and [VisualDensity.vertical] differ. The
  /// result never goes below [min].
  double gap(double value, {double min = 0}) {
    final adjustment =
        (visualDensity.baseSizeAdjustment.dx +
            visualDensity.baseSizeAdjustment.dy) /
        4;
    return math.max(min, value + adjustment);
  }

  /// Extra vertical space a row of Material controls (buttons, chips, etc.)
  /// needs when [visualDensity] is taller than the compact density used as
  /// the baseline for fixed header/app-bar heights (the default on web and
  /// desktop). Use to grow a hardcoded `Size.fromHeight` so its content
  /// doesn't overflow when the user picks a less dense/larger setting.
  double appBarExtra({double min = 0}) {
    final baseline = VisualDensity.compact.baseSizeAdjustment.dy;
    return math.max(min, visualDensity.baseSizeAdjustment.dy - baseline);
  }

  /// Builds symmetric [EdgeInsets] where both the horizontal and vertical
  /// insets start from the same [value], each scaled independently via
  /// [horizontal] and [vertical] and floored at [min].
  EdgeInsets all(double value, {double min = 0}) {
    return EdgeInsets.symmetric(
      horizontal: horizontal(value, min: min),
      vertical: vertical(value, min: min),
    );
  }

  /// Builds [EdgeInsets] mirroring [EdgeInsets.symmetric], scaling
  /// [horizontal] and [vertical] independently and flooring each at
  /// [minHorizontal] and [minVertical] respectively.
  EdgeInsets symmetric({
    double horizontal = 0,
    double vertical = 0,
    double minHorizontal = 0,
    double minVertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: this.horizontal(horizontal, min: minHorizontal),
      vertical: this.vertical(vertical, min: minVertical),
    );
  }

  /// Builds [EdgeInsets] mirroring [EdgeInsets.only], scaling each side by
  /// [horizontal] or [vertical] as appropriate and flooring the horizontal
  /// sides at [minHorizontal] and the vertical sides at [minVertical].
  EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
    double minHorizontal = 0,
    double minVertical = 0,
  }) {
    return EdgeInsets.only(
      left: horizontal(left, min: minHorizontal),
      top: vertical(top, min: minVertical),
      right: horizontal(right, min: minHorizontal),
      bottom: vertical(bottom, min: minVertical),
    );
  }
}
