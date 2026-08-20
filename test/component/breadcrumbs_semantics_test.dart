import 'package:fabric_flutter/component/breadcrumbs.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal app scaffolding required to pump a component.
Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Builds a two level breadcrumb trail whose crumbs are all interactive.
List<ButtonOptions> _buttons() => [
  ButtonOptions(label: 'Home', onTap: () {}),
  ButtonOptions(label: 'Settings', onTap: () {}),
];

void main() {
  group('Breadcrumbs', () {
    group('semantics', () {
      testWidgets('should expose a navigation landmark for the trail', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(_app(Breadcrumbs(buttons: _buttons())));

        // Assert
        // Without a localization delegate `AppLocalizations` returns the key
        // path itself, so both the raw key and the resolved label are valid.
        expect(
          find.bySemanticsLabel(RegExp('Breadcrumb navigation|breadcrumb')),
          findsWidgets,
        );
        handle.dispose();
      });

      testWidgets('should give every crumb an accessible name', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(_app(Breadcrumbs(buttons: _buttons())));

        // Assert
        expect(find.bySemanticsLabel(RegExp('Home')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp('Settings')), findsWidgets);
        handle.dispose();
      });

      testWidgets('should mark the last crumb as the current location', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(_app(Breadcrumbs(buttons: _buttons())));
        final selected = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((widget) => widget.properties.selected == true);

        // Assert
        expect(selected, isNotEmpty);
        handle.dispose();
      });

      testWidgets('should meet the labeled tap target guideline', (
        WidgetTester tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(_app(Breadcrumbs(buttons: _buttons())));

        // Assert
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  });
}
