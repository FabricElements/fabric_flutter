import 'package:flutter/material.dart';
import 'package:fabric_flutter/helper/density_spacing.dart';
import 'package:fabric_flutter/helper/material_theme.dart';
import 'package:fabric_flutter/helper/window_size.dart';

/// Seed color shared by every catalog variant so light and dark schemes stay
/// comparable across the matrix.
const Color catalogSeedColor = Color(0xFF6750A4);

/// Named [VisualDensity] values used by [DensitySpacing] in the catalog.
const List<({String name, VisualDensity value})> catalogDensities = [
  (name: 'Standard', value: VisualDensity.standard),
  (name: 'Compact', value: VisualDensity.compact),
  (name: 'Comfortable', value: VisualDensity.comfortable),
];

/// Widths in logical pixels that map to the compact, medium, and expanded
/// [WindowSizeClass] values.
const List<double> catalogWidths = [390, 700, 1000];

/// One combination of brightness, density, and window width.
class CatalogVariant {
  /// Creates a variant for the given [brightness], [density], and [width].
  const CatalogVariant({
    required this.brightness,
    required this.densityName,
    required this.density,
    required this.width,
  });

  /// Every light and dark, density, and width combination in the catalog.
  static final List<CatalogVariant> all = [
    for (final brightness in Brightness.values)
      for (final density in catalogDensities)
        for (final width in catalogWidths)
          CatalogVariant(
            brightness: brightness,
            densityName: density.name,
            density: density.value,
            width: width,
          ),
  ];

  /// Color scheme brightness.
  final Brightness brightness;

  /// Human-readable density name, for example `Standard`.
  final String densityName;

  /// The [VisualDensity] applied to the theme.
  final VisualDensity density;

  /// Available width in logical pixels.
  final double width;

  /// The [WindowSizeClass] this variant's [width] resolves to.
  WindowSizeClass get sizeClass => WindowSizeClass.fromWidth(width);

  /// Display name shown as the variant caption, for example
  /// `Light / Standard / compact (390)`.
  String get name =>
      '${brightness == Brightness.light ? 'Light' : 'Dark'} / $densityName / '
      '${sizeClass.name} (${width.toInt()})';

  /// File-safe key used to name golden images.
  String get fileKey =>
      '${brightness.name}_${densityName.toLowerCase()}_${width.toInt()}';
}

/// Renders a catalog use case inside a fixed-size frame with a theme,
/// text theme, and density chosen by [variant].
///
/// The theme, text theme, and density are read once per build, and the
/// frame's [MediaQuery] size drives [WindowSizeClass] for everything it
/// contains. Its fixed [height] keeps golden images deterministic.
class CatalogFrame extends StatelessWidget {
  /// Creates a frame that renders [builder] under [variant].
  const CatalogFrame({super.key, required this.variant, required this.builder});

  /// Fixed frame height in logical pixels.
  static const double height = 640;

  /// The brightness, density, and width this frame renders with.
  final CatalogVariant variant;

  /// Builds the use case content; it runs under the variant's theme.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final theme = MaterialThemeM3.apply(
      ThemeData(
        colorScheme: MaterialThemeM3.schemeFromSeed(
          catalogSeedColor,
          variant.brightness,
        ),
        visualDensity: variant.density,
      ),
    );
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final density = DensitySpacing(theme.visualDensity);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(variant.width, height)),
        child: Material(
          color: colorScheme.surface,
          child: SizedBox(
            width: variant.width,
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: density.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    variant.name,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Builder(builder: builder)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
