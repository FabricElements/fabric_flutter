import 'package:fabric_flutter/component/adaptive_navigation_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Key on the body so its padding can be located.
const _bodyKey = Key('adaptive-body');

/// Three destinations used by every test.
const _destinations = <AdaptiveDestination>[
  AdaptiveDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  AdaptiveDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
  AdaptiveDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
];

/// Pumps the scaffold in a window of [width] dp and returns the selections.
Future<List<int>> _pump(
  WidgetTester tester,
  double width, {
  bool applyMargin = true,
  Brightness brightness = Brightness.light,
}) async {
  final selections = <int>[];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: AdaptiveNavigationScaffold(
        destinations: _destinations,
        selectedIndex: 0,
        onDestinationSelected: selections.add,
        applyMargin: applyMargin,
        body: const SizedBox.expand(key: _bodyKey),
      ),
    ),
  );
  return selections;
}

/// Horizontal padding applied around the body.
EdgeInsets _bodyPadding(WidgetTester tester) {
  final padding = tester.widget<Padding>(
    find
        .ancestor(of: find.byKey(_bodyKey), matching: find.byType(Padding))
        .first,
  );
  return padding.padding as EdgeInsets;
}

void main() {
  group('AdaptiveNavigationScaffold', () {
    group('navigation type', () {
      testWidgets('should show a navigation bar below 600dp', (tester) async {
        // Arrange & Act
        await _pump(tester, 599);

        // Assert
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      });

      testWidgets('should show a collapsed rail at 600dp', (tester) async {
        // Arrange & Act
        await _pump(tester, 600);

        // Assert
        expect(find.byType(NavigationBar), findsNothing);
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isFalse);
        expect(rail.labelType, NavigationRailLabelType.all);
      });

      testWidgets('should keep the rail collapsed at 1199dp', (tester) async {
        // Arrange & Act
        await _pump(tester, 1199);

        // Assert
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isFalse);
      });

      testWidgets('should extend the rail from 1200dp', (tester) async {
        // Arrange & Act
        await _pump(tester, 1200);

        // Assert
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isTrue);
        expect(find.text('Settings'), findsOneWidget);
      });
    });

    group('margins', () {
      for (final (width, margin) in [
        (599.0, 16.0),
        (600.0, 24.0),
        (1199.0, 24.0),
        (1200.0, 24.0),
      ]) {
        testWidgets('should pad the body by ${margin}dp at ${width}dp', (
          tester,
        ) async {
          // Arrange & Act
          await _pump(tester, width);

          // Assert
          expect(
            _bodyPadding(tester),
            EdgeInsets.symmetric(horizontal: margin),
          );
        });
      }

      testWidgets('should not pad the body when applyMargin is false', (
        tester,
      ) async {
        // Arrange & Act
        await _pump(tester, 600, applyMargin: false);

        // Assert
        expect(
          find.ancestor(
            of: find.byKey(_bodyKey),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Padding &&
                  widget.padding == const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
          findsNothing,
        );
      });
    });

    group('selection', () {
      testWidgets('should report the tapped bar destination', (tester) async {
        // Arrange
        final selections = await _pump(tester, 390);

        // Act
        await tester.tap(find.text('Inbox'));
        await tester.pumpAndSettle();

        // Assert
        expect(selections, [1]);
      });

      testWidgets('should report the tapped rail destination', (tester) async {
        // Arrange
        final selections = await _pump(tester, 1000);

        // Act
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        // Assert
        expect(selections, [2]);
      });
    });

    group('themes', () {
      for (final brightness in Brightness.values) {
        for (final width in [390.0, 700.0, 1000.0]) {
          testWidgets(
            'should render without overflow at ${width}dp in ${brightness.name}',
            (tester) async {
              // Arrange & Act
              await _pump(tester, width, brightness: brightness);

              // Assert
              expect(tester.takeException(), isNull);
              expect(find.byKey(_bodyKey), findsOneWidget);
            },
          );
        }
      }
    });
  });
}
