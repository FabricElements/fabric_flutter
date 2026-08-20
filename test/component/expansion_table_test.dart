import 'package:fabric_flutter/component/expansion_table.dart';
import 'package:fabric_flutter/serialized/table_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TableData _sample() => TableData(
  header: [
    TableColumnData(value: 'Name'),
    TableColumnData(value: 'Age', type: TableDataType.number),
  ],
  rows: [
    TableRowData(cells: ['Bob', 30]),
    TableRowData(
      cells: ['Ann', 25],
      child: TableData(
        header: [
          TableColumnData(value: 'Name'),
          TableColumnData(value: 'Age', type: TableDataType.number),
        ],
        rows: [
          TableRowData(cells: ['Kid', 5]),
        ],
      ),
    ),
  ],
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ExpansionTable', () {
    testWidgets('should render an empty box when data is null', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(ExpansionTable(data: null)));

      // Assert
      expect(tester.takeException(), isNull);
    });

    testWidgets('should render header labels and row cells', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(ExpansionTable(data: _sample())));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Ann'), findsOneWidget);
    });

    testWidgets('should expand a nested child table when toggled', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(ExpansionTable(data: _sample())));
      await tester.pumpAndSettle();
      expect(find.text('Kid'), findsNothing);

      // Act
      await tester.tap(find.byIcon(Icons.arrow_right).first);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Kid'), findsOneWidget);
    });

    testWidgets('should dispose cleanly when removed from the tree', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(ExpansionTable(data: _sample())));
      await tester.pumpAndSettle();

      // Act — replacing the widget triggers State.dispose
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
    });
  });
}
