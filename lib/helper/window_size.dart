import 'package:flutter/widgets.dart';

/// Material 3 window size classes, derived from the available width in
/// logical pixels (dp).
///
/// Breakpoints follow the Material 3 layout guidance:
///
/// | Class        | Width (dp)        |
/// | ------------ | ----------------- |
/// | [compact]    | below 600         |
/// | [medium]     | 600 to 839        |
/// | [expanded]   | 840 to 1199       |
/// | [large]      | 1200 to 1599      |
/// | [extraLarge] | 1600 and up       |
///
/// Prefer [WindowSizeClass.of] inside a `build` method; use
/// [WindowSizeClass.fromWidth] when you already have a width, for example
/// from a [LayoutBuilder]'s constraints.
enum WindowSizeClass {
  /// Width below 600dp — phones in portrait.
  compact,

  /// Width from 600dp to 839dp — tablets in portrait, foldables.
  medium,

  /// Width from 840dp to 1199dp — tablets in landscape, small desktops.
  expanded,

  /// Width from 1200dp to 1599dp — desktops.
  large,

  /// Width of 1600dp and up — large desktops.
  extraLarge;

  /// Lower bound (inclusive) of [medium], in dp.
  static const double mediumMinWidth = 600;

  /// Lower bound (inclusive) of [expanded], in dp.
  static const double expandedMinWidth = 840;

  /// Lower bound (inclusive) of [large], in dp.
  static const double largeMinWidth = 1200;

  /// Lower bound (inclusive) of [extraLarge], in dp.
  static const double extraLargeMinWidth = 1600;

  /// Returns the size class for a [width] in logical pixels.
  ///
  /// Negative or non-finite widths resolve to [compact].
  static WindowSizeClass fromWidth(double width) {
    if (width.isNaN || width < mediumMinWidth) return compact;
    if (width < expandedMinWidth) return medium;
    if (width < largeMinWidth) return expanded;
    if (width < extraLargeMinWidth) return large;
    return extraLarge;
  }

  /// Returns the size class for the width of the ambient [MediaQuery].
  ///
  /// Only rebuilds [context] when the window size changes.
  static WindowSizeClass of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  /// Whether this class is at least as wide as [other].
  bool isAtLeast(WindowSizeClass other) => index >= other.index;

  /// Recommended horizontal window margin in dp for this class: 16dp for
  /// [compact], 24dp otherwise.
  double get margin => this == compact ? 16 : 24;

  /// Recommended spacing between panes in dp. Material 3 uses a 24dp
  /// spacer between panes on every size class that shows more than one.
  double get paneSpacing => 24;
}
