import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fabric_flutter/helper/material_theme.dart';

void main() {
  group('MaterialThemeM3', () {
    group('apply', () {
      test('should keep the base typography', () {
        // Arrange
        final base = ThemeData(
          textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 21)),
        );

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.textTheme.bodyLarge?.fontSize, 21);
      });

      test('should keep the base color scheme', () {
        // Arrange
        final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
        final base = ThemeData(colorScheme: scheme);

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.colorScheme, scheme);
      });

      test('should use surfaceContainerLow for cards without tint', () {
        // Arrange
        final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
        final base = ThemeData(colorScheme: scheme);

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.cardTheme.color, scheme.surfaceContainerLow);
        expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
        expect(theme.cardTheme.elevation, 0);
      });

      test('should use surfaceContainerHigh for dialogs without tint', () {
        // Arrange
        final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
        final base = ThemeData(colorScheme: scheme);

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.dialogTheme.backgroundColor, scheme.surfaceContainerHigh);
        expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
        expect(theme.dialogTheme.elevation, 0);
      });
    });
  });
}
