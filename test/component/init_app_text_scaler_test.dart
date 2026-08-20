import 'package:fabric_flutter/component/init_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clampedTextScaler', () {
    test('should keep the operating system text scale within bounds', () {
      // Arrange
      const osScaler = TextScaler.linear(1.3);

      // Act
      final result = clampedTextScaler(
        osScaler,
        min: kDefaultMinTextScaleFactor,
        max: kDefaultMaxTextScaleFactor,
      );

      // Assert
      expect(result.scale(10), 13);
      expect(result, isNot(TextScaler.noScaling));
    });

    test('should clamp the text scale to the configured maximum', () {
      // Arrange
      const osScaler = TextScaler.linear(3.0);

      // Act
      final result = clampedTextScaler(
        osScaler,
        min: kDefaultMinTextScaleFactor,
        max: kDefaultMaxTextScaleFactor,
      );

      // Assert
      expect(result.scale(10), 10 * kDefaultMaxTextScaleFactor);
    });

    test('should clamp the text scale to the configured minimum', () {
      // Arrange
      const osScaler = TextScaler.linear(0.5);

      // Act
      final result = clampedTextScaler(
        osScaler,
        min: kDefaultMinTextScaleFactor,
        max: kDefaultMaxTextScaleFactor,
      );

      // Assert
      expect(result.scale(10), 10 * kDefaultMinTextScaleFactor);
    });

    test('should apply no clamp when both bounds are null', () {
      // Arrange
      const osScaler = TextScaler.linear(2.5);

      // Act
      final result = clampedTextScaler(osScaler);

      // Assert
      expect(identical(result, osScaler), isTrue);
      expect(result.scale(10), 25);
    });

    test('should respect a custom maximum text scale factor', () {
      // Arrange
      const osScaler = TextScaler.linear(4.0);

      // Act
      final result = clampedTextScaler(osScaler, max: 2.0);

      // Assert
      expect(result.scale(10), 20);
    });

    test('should apply the bounds only when a caller opts in', () {
      // Arrange
      const osScaler = TextScaler.linear(2.0);

      // Act
      final result = clampedTextScaler(
        osScaler,
        min: kDefaultMinTextScaleFactor,
        max: kDefaultMaxTextScaleFactor,
      );

      // Assert: opting in keeps scaling active, just bounded.
      expect(result.scale(10), greaterThan(10));
      expect(result.scale(10), 10 * kDefaultMaxTextScaleFactor);
    });
  });

  group('InitApp text scaling defaults', () {
    test('should disable text scaling by default', () {
      // Arrange & Act
      const widget = InitApp(child: SizedBox.shrink());

      // Assert: disabling the OS text scale is deliberate. Honoring it caused a
      // layout bug on iOS, so consumers must opt in explicitly.
      expect(widget.honorSystemTextScale, isFalse);
    });

    test('should disable text scaling by default on InitAppChild', () {
      // Arrange & Act
      const widget = InitAppChild(child: SizedBox.shrink());

      // Assert
      expect(widget.honorSystemTextScale, isFalse);
    });

    test('should forward the opt-in flag and bounds when enabled', () {
      // Arrange & Act
      const widget = InitApp(
        honorSystemTextScale: true,
        minTextScaleFactor: 0.9,
        maxTextScaleFactor: 1.2,
        child: SizedBox.shrink(),
      );

      // Assert
      expect(widget.honorSystemTextScale, isTrue);
      expect(widget.minTextScaleFactor, 0.9);
      expect(widget.maxTextScaleFactor, 1.2);
    });

    test('should default the opt-in bounds to the layout-safe range', () {
      // Arrange & Act
      const widget = InitApp(child: SizedBox.shrink());

      // Assert: the bounds are unused until honorSystemTextScale is enabled.
      expect(widget.minTextScaleFactor, kDefaultMinTextScaleFactor);
      expect(widget.maxTextScaleFactor, kDefaultMaxTextScaleFactor);
    });
  });
}
