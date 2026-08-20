import 'package:fabric_flutter/component/init_app.dart';
import 'package:fabric_flutter/state/state_analytics.dart';
import 'package:fabric_flutter/state/state_global.dart';
import 'package:fabric_flutter/state/state_notifications.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/firebase_test_harness.dart';

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

/// Wraps [child] in the state providers [InitAppChild] reads during bootstrap
/// so it can be pumped inside a test without a real Firebase backend.
///
/// The providers mirror the subset of the tree that [InitApp] installs and that
/// [InitAppChild.initState] and [InitAppChild.build] look up through `Provider`.
Widget _wrapInitAppChild(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => StateGlobal()),
      ChangeNotifierProvider(create: (_) => StateNotifications()),
      ChangeNotifierProvider(create: (_) => StateUser()),
      ChangeNotifierProvider(create: (_) => StateAnalytics()),
    ],
    child: child,
  );
}

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

    test('should leave an exactly-at-bound value untouched', () {
      // Arrange: the scale factor sits exactly on the upper bound.
      const osScaler = TextScaler.linear(1.4);

      // Act
      final result = clampedTextScaler(osScaler, min: 1.0, max: 1.4);

      // Assert: an at-bound value is neither clamped nor altered.
      expect(result.scale(10), 10 * 1.4);
    });

    test('should clamp only the minimum when the maximum is null', () {
      // Arrange
      const osScaler = TextScaler.linear(0.25);

      // Act
      final result = clampedTextScaler(osScaler, min: 1.0);

      // Assert
      expect(result.scale(10), 10);
    });

    test('should preserve a non-linear scaler that stays within bounds', () {
      // Arrange: the stepped scaler doubles sizes <= 20, i.e. factor 2.
      const osScaler = _StepTextScaler();

      // Act
      final result = clampedTextScaler(osScaler, min: 1.0, max: 3.0);

      // Assert: 15 -> 30 stays untouched because 2x is inside [1, 3].
      expect(result.scale(15), 30);
    });

    test('should clamp a non-linear scaler that exceeds the maximum', () {
      // Arrange: for sizes > 20 the stepped scaler triples (factor 3).
      const osScaler = _StepTextScaler();

      // Act
      final result = clampedTextScaler(osScaler, min: 1.0, max: 2.0);

      // Assert: 30 would triple to 90 but is capped at 30 * 2.0.
      expect(result.scale(30), 30 * 2.0);
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

  group('InitAppChild rendered text scaling', () {
    setUpAll(() async {
      // Arrange: mock Firebase so StateUser and friends are constructible.
      await setupFirebaseForTest();
    });

    testWidgets('should apply no scaling to descendants by default', (
      tester,
    ) async {
      // Arrange: the platform reports a large OS text scale. This is a
      // REGRESSION GUARD. Ignoring the OS text scale is deliberate: honoring
      // it caused a layout bug on iOS and has been "fixed" by mistake once
      // already. If InitAppChild.build ever clamps unconditionally instead of
      // returning TextScaler.noScaling, this test must fail — the plain
      // constructor-field tests above would not catch that.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      late TextScaler seen;

      // Act: pump InitAppChild with default parameters and capture the
      // scaler an actual descendant receives, not a constructor field.
      await tester.pumpWidget(
        _wrapInitAppChild(
          InitAppChild(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.textScalerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Assert: the descendant sees no scaling despite the 2.0 OS setting.
      expect(seen, TextScaler.noScaling);
      expect(seen.scale(10), 10);
    });

    testWidgets('should clamp the OS scale for descendants when opted in', (
      tester,
    ) async {
      // Arrange: opt in explicitly with a large OS scale that exceeds the
      // configured maximum, so the mirror of the default behavior is proven.
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      late TextScaler seen;

      // Act
      await tester.pumpWidget(
        _wrapInitAppChild(
          InitAppChild(
            honorSystemTextScale: true,
            maxTextScaleFactor: 1.4,
            child: Builder(
              builder: (context) {
                seen = MediaQuery.textScalerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Assert: the descendant now scales, clamped to the configured maximum.
      expect(seen, isNot(TextScaler.noScaling));
      expect(seen.scale(10), 10 * 1.4);
    });
  });
}
