import 'package:fabric_flutter/helper/material_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the WCAG 2.x contrast ratio between [a] and [b].
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Returns the shortest angular distance between two hues, in degrees.
double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  /// Brand seeds covering warm, cool, saturated, and muted hues.
  const seeds = <Color>[
    Color(0xFF6750A4),
    Color(0xFF0B57D0),
    Color(0xFFB3261E),
    Color(0xFF146C2E),
    Color(0xFFE8710A),
    Color(0xFF00696E),
  ];

  group('MaterialThemeM3.schemeFromSeed', () {
    for (final seed in seeds) {
      for (final brightness in Brightness.values) {
        final label = '${seed.toARGB32().toRadixString(16)} $brightness';

        test('should keep the seed hue in primary for $label', () {
          // Arrange
          final seedHsl = HSLColor.fromColor(seed);

          // Act
          final scheme = MaterialThemeM3.schemeFromSeed(seed, brightness);
          final primaryHsl = HSLColor.fromColor(scheme.primary);

          // Assert
          expect(scheme.brightness, brightness);
          expect(_hueDistance(seedHsl.hue, primaryHsl.hue), lessThan(15));
        });

        test('should meet 4.5:1 text contrast for $label', () {
          // Arrange
          final scheme = MaterialThemeM3.schemeFromSeed(seed, brightness);

          // Act
          final pairs = <String, double>{
            'onPrimary/primary': _contrast(scheme.onPrimary, scheme.primary),
            'onPrimaryContainer/primaryContainer': _contrast(
              scheme.onPrimaryContainer,
              scheme.primaryContainer,
            ),
            'onSurface/surface': _contrast(scheme.onSurface, scheme.surface),
            'onSurfaceVariant/surface': _contrast(
              scheme.onSurfaceVariant,
              scheme.surface,
            ),
            'onError/error': _contrast(scheme.onError, scheme.error),
          };

          // Assert
          pairs.forEach((name, ratio) {
            expect(ratio, greaterThanOrEqualTo(4.5), reason: name);
          });
        });

        test('should meet 3:1 UI contrast for $label', () {
          // Arrange
          final scheme = MaterialThemeM3.schemeFromSeed(seed, brightness);

          // Act
          final outline = _contrast(scheme.outline, scheme.surface);
          final primary = _contrast(scheme.primary, scheme.surface);

          // Assert
          expect(outline, greaterThanOrEqualTo(3.0), reason: 'outline');
          expect(primary, greaterThanOrEqualTo(3.0), reason: 'primary');
        });
      }
    }
  });
}
