import 'package:fabric_flutter/component/tabs.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal Material scaffolding [Tabs] expects.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Builds [count] tab options, marking [selected] as the active entry.
List<ButtonOptions> _tabs(int count, {int selected = 0}) => List.generate(
  count,
  (i) => ButtonOptions(label: 'Tab $i', selected: i == selected),
);

void main() {
  group('Tabs', () {
    testWidgets('should render one tab per option', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(Tabs(tabs: _tabs(3))));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(Tab), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('should rebuild the controller when tabs are added', (
      tester,
    ) async {
      // Arrange — a TabController has a fixed length, so growing the list
      // without recreating it trips a framework assertion inside TabBar.
      await tester.pumpWidget(_wrap(Tabs(tabs: _tabs(2))));
      await tester.pumpAndSettle();

      // Act
      await tester.pumpWidget(_wrap(Tabs(tabs: _tabs(4))));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(Tab), findsNWidgets(4));
    });

    testWidgets('should rebuild the controller when tabs are removed', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(Tabs(tabs: _tabs(4))));
      await tester.pumpAndSettle();

      // Act
      await tester.pumpWidget(_wrap(Tabs(tabs: _tabs(2))));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(Tab), findsNWidgets(2));
    });

    testWidgets('should tolerate a list with no selected option', (
      tester,
    ) async {
      // Arrange — indexWhere returns -1 when nothing is marked selected, which
      // is not a valid TabController index.
      final tabs = _tabs(3, selected: -1);

      // Act
      await tester.pumpWidget(_wrap(Tabs(tabs: tabs)));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(Tab), findsNWidgets(3));
    });

    testWidgets('should dispose cleanly when removed from the tree', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(Tabs(tabs: _tabs(3))));
      await tester.pumpAndSettle();

      // Act
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
    });
  });
}
