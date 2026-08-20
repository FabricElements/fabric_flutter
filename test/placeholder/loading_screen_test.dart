import 'package:fabric_flutter/placeholder/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a minimal [MaterialApp] so theme lookups resolve.
Future<void> pumpScreen(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  group('LoadingScreen', () {
    testWidgets('should render an adaptive progress indicator', (tester) async {
      // Arrange
      const screen = LoadingScreen();

      // Act
      await pumpScreen(tester, screen);

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render an indeterminate indicator', (tester) async {
      // Arrange
      const screen = LoadingScreen();

      // Act
      await pumpScreen(tester, screen);

      // Assert
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('should omit the AppBar by default', (tester) async {
      // Arrange
      const screen = LoadingScreen();

      // Act
      await pumpScreen(tester, screen);

      // Assert
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('should render an AppBar when parent is true', (tester) async {
      // Arrange
      const screen = LoadingScreen(parent: true);

      // Act
      await pumpScreen(tester, screen);

      // Assert
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should center the indicator between two spacers', (
      tester,
    ) async {
      // Arrange
      const screen = LoadingScreen();

      // Act
      await pumpScreen(tester, screen);

      // Assert
      expect(find.byType(Spacer), findsNWidgets(2));
    });

    testWidgets('should paint the surface color as the background', (
      tester,
    ) async {
      // Arrange
      final theme = ThemeData.light();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: LoadingScreen()),
        ),
      );

      // Assert
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, theme.colorScheme.surface);
    });
  });
}
