import 'package:fabric_flutter/component/adaptive_navigation_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a scaffold with semantics hooks in a window of [width] dp.
Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AdaptiveNavigationScaffold(
        destinations: const [
          AdaptiveDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          AdaptiveDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
        ],
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        semanticsLabel: 'Main navigation',
        automationKey: 'app_shell_navigation_main',
        semanticHint: 'Switch between top-level sections',
        body: const SizedBox.expand(),
      ),
    ),
  );
}

void main() {
  group('AdaptiveNavigationScaffold', () {
    group('semantics', () {
      for (final width in [390.0, 1000.0, 1300.0]) {
        testWidgets('should expose label, identifier and hint at ${width}dp', (
          tester,
        ) async {
          // Arrange
          final handle = tester.ensureSemantics();

          // Act
          await _pump(tester, width);

          // Assert
          final nodes = tester
              .widgetList<Semantics>(find.byType(Semantics))
              .where(
                (widget) =>
                    widget.properties.identifier == 'app_shell_navigation_main',
              );
          expect(nodes, hasLength(1));
          expect(nodes.single.properties.label, 'Main navigation');
          expect(
            nodes.single.properties.hint,
            'Switch between top-level sections',
          );
          handle.dispose();
        });
      }

      testWidgets('should give every destination an accessible name', (
        tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await _pump(tester, 390);

        // Assert
        expect(find.bySemanticsLabel(RegExp('Home')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp('Inbox')), findsWidgets);
        handle.dispose();
      });
    });
  });
}
