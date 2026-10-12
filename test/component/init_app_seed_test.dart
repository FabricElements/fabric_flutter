import 'package:fabric_flutter/component/init_app.dart';
import 'package:fabric_flutter/helper/material_theme.dart';
import 'package:fabric_flutter/state/state_analytics.dart';
import 'package:fabric_flutter/state/state_global.dart';
import 'package:fabric_flutter/state/state_notifications.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/firebase_test_harness.dart';

/// Wraps [child] in the state providers [InitAppChild] reads during bootstrap
/// so it can be pumped inside a test without a real Firebase backend.
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

/// Pumps [InitAppChild] with [seedColor] under [brightness] and returns the
/// [ColorScheme] a descendant actually receives.
Future<ColorScheme> _pumpAndReadScheme(
  WidgetTester tester, {
  required Brightness brightness,
  Color? seedColor,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  late ColorScheme seen;
  await tester.pumpWidget(
    _wrapInitAppChild(
      InitAppChild(
        seedColor: seedColor,
        child: Builder(
          builder: (context) {
            seen = Theme.of(context).colorScheme;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return seen;
}

void main() {
  group('InitAppChild seed color scheme', () {
    setUpAll(() async {
      // Arrange: mock Firebase so StateUser and friends are constructible.
      await setupFirebaseForTest();
    });

    for (final brightness in Brightness.values) {
      testWidgets('should derive the ${brightness.name} scheme from the seed', (
        tester,
      ) async {
        // Arrange
        const seed = Color(0xFF0B57D0);

        // Act
        final scheme = await _pumpAndReadScheme(
          tester,
          brightness: brightness,
          seedColor: seed,
        );

        // Assert
        final expected = MaterialThemeM3.schemeFromSeed(seed, brightness);
        expect(scheme.brightness, brightness);
        expect(scheme.primary, expected.primary);
        expect(scheme.surface, expected.surface);
      });
    }

    testWidgets('should fall back to the ambient primary without a seed', (
      tester,
    ) async {
      // Arrange
      final ambientPrimary = ThemeData.light().colorScheme.primary;

      // Act
      final scheme = await _pumpAndReadScheme(
        tester,
        brightness: Brightness.dark,
      );

      // Assert
      final expected = MaterialThemeM3.schemeFromSeed(
        ambientPrimary,
        Brightness.dark,
      );
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, expected.primary);
    });
  });
}
