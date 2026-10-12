import 'package:flutter/material.dart';

import 'm3_tokens.dart';

/// Applies Material 3 defaults to a [ThemeData] without changing its color
/// seed, typography sizes, or geometry.
///
/// Consumers keep control of their brand colors through the base theme.
/// This helper only ensures Material 3 is enabled and that shared surfaces
/// and components use the M3 tonal color roles, flat elevation, and the
/// [M3Shape] scale rather than elevation tint.
///
/// Component defaults (app bar, navigation, FAB, chips, inputs, snack bars,
/// sheets, menus, tooltips) are only filled in where the base theme leaves a
/// value unset, so consumer overrides always win.
///
/// ```dart
/// final theme = MaterialThemeM3.apply(ThemeData.light());
/// ```
class MaterialThemeM3 {
  const MaterialThemeM3._();

  /// Returns a Material 3 [ColorScheme] derived from a brand [seed] for the
  /// given [brightness].
  ///
  /// Uses [DynamicSchemeVariant.fidelity] so the light and dark primary roles
  /// stay close to the seed's hue and chroma, while the tonal palette keeps
  /// the M3 contrast pairs (`on*` roles against their containers) legible in
  /// both brightnesses.
  ///
  /// ```dart
  /// final dark = MaterialThemeM3.schemeFromSeed(
  ///   const Color(0xFF6750A4),
  ///   Brightness.dark,
  /// );
  /// ```
  static ColorScheme schemeFromSeed(Color seed, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  }

  /// Returns [base] with M3 surface roles applied to card and dialog themes
  /// and M3 defaults applied to unset component theme values.
  ///
  /// Material 3 is the default in current Flutter, so `useMaterial3` is not
  /// set here (the flag is deprecated). Typography sizes are intentionally
  /// left untouched.
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
      appBarTheme: _appBarTheme(base.appBarTheme, scheme),
      navigationBarTheme: _navigationBarTheme(base.navigationBarTheme, scheme),
      navigationRailTheme: _navigationRailTheme(
        base.navigationRailTheme,
        scheme,
      ),
      drawerTheme: _drawerTheme(base.drawerTheme, scheme),
      floatingActionButtonTheme: _fabTheme(
        base.floatingActionButtonTheme,
        scheme,
      ),
      chipTheme: _chipTheme(base.chipTheme, scheme),
      inputDecorationTheme: _inputDecorationTheme(
        base.inputDecorationTheme,
        scheme,
      ),
      snackBarTheme: _snackBarTheme(base.snackBarTheme, scheme),
      bottomSheetTheme: _bottomSheetTheme(base.bottomSheetTheme, scheme),
      popupMenuTheme: _popupMenuTheme(base.popupMenuTheme, scheme),
      tooltipTheme: _tooltipTheme(base.tooltipTheme, scheme),
    );
  }

  /// Flat app bar on [ColorScheme.surface] that stays flat when content
  /// scrolls underneath.
  static AppBarThemeData _appBarTheme(
    AppBarThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      backgroundColor: theme.backgroundColor ?? scheme.surface,
      foregroundColor: theme.foregroundColor ?? scheme.onSurface,
      elevation: theme.elevation ?? 0,
      scrolledUnderElevation: theme.scrolledUnderElevation ?? 0,
      surfaceTintColor: theme.surfaceTintColor ?? Colors.transparent,
    );
  }

  /// Navigation bar on [ColorScheme.surfaceContainer] with a
  /// [ColorScheme.secondaryContainer] indicator.
  static NavigationBarThemeData _navigationBarTheme(
    NavigationBarThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      backgroundColor: theme.backgroundColor ?? scheme.surfaceContainer,
      indicatorColor: theme.indicatorColor ?? scheme.secondaryContainer,
      elevation: theme.elevation ?? 0,
      surfaceTintColor: theme.surfaceTintColor ?? Colors.transparent,
    );
  }

  /// Navigation rail on [ColorScheme.surface] with a
  /// [ColorScheme.secondaryContainer] indicator.
  static NavigationRailThemeData _navigationRailTheme(
    NavigationRailThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      backgroundColor: theme.backgroundColor ?? scheme.surface,
      indicatorColor: theme.indicatorColor ?? scheme.secondaryContainer,
      elevation: theme.elevation ?? 0,
    );
  }

  /// Flat drawer on [ColorScheme.surfaceContainerLow].
  static DrawerThemeData _drawerTheme(
    DrawerThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      backgroundColor: theme.backgroundColor ?? scheme.surfaceContainerLow,
      surfaceTintColor: theme.surfaceTintColor ?? Colors.transparent,
      elevation: theme.elevation ?? 0,
    );
  }

  /// Flat FAB on [ColorScheme.primaryContainer] with the
  /// [M3Shape.large] corner.
  static FloatingActionButtonThemeData _fabTheme(
    FloatingActionButtonThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      backgroundColor: theme.backgroundColor ?? scheme.primaryContainer,
      foregroundColor: theme.foregroundColor ?? scheme.onPrimaryContainer,
      elevation: theme.elevation ?? 0,
      focusElevation: theme.focusElevation ?? 0,
      hoverElevation: theme.hoverElevation ?? 0,
      highlightElevation: theme.highlightElevation ?? 0,
      shape:
          theme.shape ??
          RoundedRectangleBorder(borderRadius: M3Shape.circular(M3Shape.large)),
    );
  }

  /// Chips with an [ColorScheme.outlineVariant] outline and the
  /// [M3Shape.small] corner.
  static ChipThemeData _chipTheme(ChipThemeData theme, ColorScheme scheme) {
    return theme.copyWith(
      side: theme.side ?? BorderSide(color: scheme.outlineVariant),
      shape:
          theme.shape ??
          RoundedRectangleBorder(borderRadius: M3Shape.circular(M3Shape.small)),
      elevation: theme.elevation ?? 0,
      pressElevation: theme.pressElevation ?? 0,
    );
  }

  /// Outlined text fields with the [M3Shape.extraSmall] corner, an
  /// [ColorScheme.outline] border, and a [ColorScheme.primary] focus border.
  static InputDecorationThemeData _inputDecorationTheme(
    InputDecorationThemeData theme,
    ColorScheme scheme,
  ) {
    final radius = M3Shape.circular(M3Shape.extraSmall);
    return theme.copyWith(
      border: theme.border ?? OutlineInputBorder(borderRadius: radius),
      enabledBorder:
          theme.enabledBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.outline),
          ),
      focusedBorder:
          theme.focusedBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
      errorBorder:
          theme.errorBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.error),
          ),
      focusedErrorBorder:
          theme.focusedErrorBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.error, width: 2),
          ),
      disabledBorder:
          theme.disabledBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: scheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
    );
  }

  /// Floating snack bar on [ColorScheme.inverseSurface] with the
  /// [M3Shape.extraSmall] corner.
  static SnackBarThemeData _snackBarTheme(
    SnackBarThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      behavior: theme.behavior ?? SnackBarBehavior.floating,
      backgroundColor: theme.backgroundColor ?? scheme.inverseSurface,
      actionTextColor: theme.actionTextColor ?? scheme.inversePrimary,
      elevation: theme.elevation ?? 0,
      shape:
          theme.shape ??
          RoundedRectangleBorder(
            borderRadius: M3Shape.circular(M3Shape.extraSmall),
          ),
    );
  }

  /// Flat bottom sheet on [ColorScheme.surfaceContainerLow] with
  /// [M3Shape.extraLarge] top corners.
  static BottomSheetThemeData _bottomSheetTheme(
    BottomSheetThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      backgroundColor: theme.backgroundColor ?? scheme.surfaceContainerLow,
      modalBackgroundColor:
          theme.modalBackgroundColor ?? scheme.surfaceContainerLow,
      surfaceTintColor: theme.surfaceTintColor ?? Colors.transparent,
      elevation: theme.elevation ?? 0,
      modalElevation: theme.modalElevation ?? 0,
      shape:
          theme.shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(M3Shape.extraLarge),
            ),
          ),
    );
  }

  /// Popup menus on [ColorScheme.surfaceContainer] with an
  /// [ColorScheme.outlineVariant] outline instead of a shadow.
  static PopupMenuThemeData _popupMenuTheme(
    PopupMenuThemeData theme,
    ColorScheme scheme,
  ) {
    return theme.copyWith(
      color: theme.color ?? scheme.surfaceContainer,
      surfaceTintColor: theme.surfaceTintColor ?? Colors.transparent,
      elevation: theme.elevation ?? 0,
      shape:
          theme.shape ??
          RoundedRectangleBorder(
            borderRadius: M3Shape.circular(M3Shape.extraSmall),
            side: BorderSide(color: scheme.outlineVariant),
          ),
    );
  }

  /// Plain tooltips on [ColorScheme.inverseSurface] with the
  /// [M3Shape.extraSmall] corner.
  static TooltipThemeData _tooltipTheme(
    TooltipThemeData theme,
    ColorScheme scheme,
  ) {
    if (theme.decoration != null) return theme;
    return theme.copyWith(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: M3Shape.circular(M3Shape.extraSmall),
      ),
    );
  }
}
