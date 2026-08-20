import 'package:fabric_flutter/component/init_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deliberately non-linear [TextScaler] used to prove that
/// [clampedTextScaler] composes with (rather than replaces) an arbitrary
/// scaler: it doubles anything at or below 20 and triples everything larger.
class _StepTextScaler extends TextScaler {
  /// Creates the stepped scaler.
  const _StepTextScaler();

  @override
  double scale(double fontSize) => fontSize <= 20 ? fontSize * 2 : fontSize * 3;

  @override
  double get textScaleFactor => 2;
}

void main() {
  group('clampedTextScaler', () {
    group('bounds', () {
      test('should clamp a value below the minimum up to the minimum', () {
        // Arrange
        const scaler = TextScaler.linear(0.5);

        // Act
        final result = clampedTextScaler(scaler, min: 1.0, max: 1.4);

        // Assert
        expect(result.scale(10), 10 * 1.0);
      });

      test('should clamp a value above the maximum down to the maximum', () {
        // Arrange
        const scaler = TextScaler.linear(3.0);

        // Act
        final result = clampedTextScaler(scaler, min: 1.0, max: 1.4);

        // Assert
        expect(result.scale(10), 10 * 1.4);
      });

      test('should leave an exactly-at-bound value untouched', () {
        // Arrange
        const scaler = TextScaler.linear(1.4);

        // Act
        final result = clampedTextScaler(scaler, min: 1.0, max: 1.4);

        // Assert
        expect(result.scale(10), 10 * 1.4);
      });

      test('should pass a value already inside the range through unchanged', () {
        // Arrange
        const scaler = TextScaler.linear(1.2);

        // Act
        final result = clampedTextScaler(scaler, min: 1.0, max: 1.4);

        // Assert
        expect(result.scale(10), closeTo(12, 0.0001));
      });
    });

    group('null bounds', () {
      test('should return the original scaler when both bounds are null', () {
        // Arrange
        const scaler = TextScaler.linear(2.5);

        // Act
        final result = clampedTextScaler(scaler);

        // Assert
        expect(identical(result, scaler), isTrue);
        expect(result.scale(10), 25);
      });

      test('should clamp only the maximum when the minimum is null', () {
        // Arrange
        const scaler = TextScaler.linear(4.0);

        // Act
        final result = clampedTextScaler(scaler, max: 2.0);

        // Assert
        expect(result.scale(10), 20);
      });

      test('should clamp only the minimum when the maximum is null', () {
        // Arrange
        const scaler = TextScaler.linear(0.25);

        // Act
        final result = clampedTextScaler(scaler, min: 1.0);

        // Assert
        expect(result.scale(10), 10);
      });
    });

    group('non-linear composition', () {
      test('should preserve a non-linear scaler that stays within bounds', () {
        // Arrange – the stepped scaler doubles sizes <= 20, i.e. factor 2.
        const scaler = _StepTextScaler();

        // Act
        final result = clampedTextScaler(scaler, min: 1.0, max: 3.0);

        // Assert – 15 -> 30 stays untouched because 2x is inside [1, 3].
        expect(result.scale(15), 30);
      });

      test('should clamp a non-linear scaler that exceeds the maximum', () {
        // Arrange – for sizes > 20 the stepped scaler triples (factor 3).
        const scaler = _StepTextScaler();

        // Act
        final result = clampedTextScaler(scaler, min: 1.0, max: 2.0);

        // Assert – 30 would triple to 90 but is capped at 30 * 2.0.
        expect(result.scale(30), 30 * 2.0);
      });
    });
  });
}
