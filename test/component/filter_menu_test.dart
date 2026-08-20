import 'package:fabric_flutter/component/filter_menu.dart';
import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/serialized/filter_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FilterMenu', () {
    testWidgets('should render an active filter chip with its label', (
      tester,
    ) async {
      // Arrange
      final data = [
        FilterData(
          id: 'name',
          label: 'Name',
          type: InputDataType.string,
          operator: FilterOperator.equal,
          value: 'Bob',
          index: 0,
        ),
      ];

      // Act
      await tester.pumpWidget(_wrap(FilterMenu(data: data, onChange: (_) {})));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Name'), findsOneWidget);
    });

    testWidgets('should refresh the mirror when the parent swaps data', (
      tester,
    ) async {
      // Arrange
      FilterData active(String label) => FilterData(
        id: 'name',
        label: label,
        type: InputDataType.string,
        operator: FilterOperator.equal,
        value: 'Bob',
        index: 0,
      );

      // Act
      await tester.pumpWidget(
        _wrap(FilterMenu(data: [active('Name')], onChange: (_) {})),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _wrap(FilterMenu(data: [active('Fullname')], onChange: (_) {})),
      );
      await tester.pumpAndSettle();

      // Assert — didUpdateWidget -> _update propagated the new label
      expect(find.textContaining('Fullname'), findsOneWidget);
      expect(find.textContaining('Name '), findsNothing);
    });

    testWidgets('should render a pending filter as an add control', (
      tester,
    ) async {
      // Arrange
      final data = [
        FilterData(id: 'name', label: 'Name', type: InputDataType.string),
      ];

      // Act
      await tester.pumpWidget(_wrap(FilterMenu(data: data, onChange: (_) {})));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(SearchAnchor), findsOneWidget);
    });
  });

  group('FilterMenuOptionData', () {
    testWidgets('should build the operator editor without errors', (
      tester,
    ) async {
      // Arrange
      final data = FilterData(
        id: 'age',
        label: 'Age',
        type: InputDataType.int,
        operator: FilterOperator.equal,
        value: '18',
      );

      // Act
      await tester.pumpWidget(
        _wrap(FilterMenuOptionData(data: data, onChange: (_) {})),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(FilterMenuOptionData), findsOneWidget);
    });
  });
}
