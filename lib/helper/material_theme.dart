import 'package:flutter/material.dart';

/// Applies Material 3 defaults to a [ThemeData] without changing its color
/// seed, typography sizes, or geometry.
///
/// Consumers keep control of their brand colors through the base theme.
/// This helper only ensures Material 3 is enabled and that the shared
/// surface containers (cards, dialogs) use the M3 surface-tone roles rather
/// than elevation tint.
///
/// ```dart
/// final theme = MaterialThemeM3.apply(ThemeData.light());
/// ```
class MaterialThemeM3 {
  const MaterialThemeM3._();

  /// Returns [base] with M3 surface roles applied to card and dialog themes.
  ///
  /// Material 3 is the default in current Flutter, so `useMaterial3` is not
  /// set here (the flag is deprecated). Shape, radius, and typography sizes
  /// are intentionally left untouched.
  static ThemeData apply(ThemeData base) {
    final scheme = base.colorScheme;
    return base.copyWith(
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
