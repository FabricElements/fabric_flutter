import 'package:fabric_flutter/component/input_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('parseValueByInputDataType', () {
    group('phone', () {
      test('should strip formatting and prefix a single plus sign', () {
        // Arrange
        const raw = '+1 (415) 555-2671';

        // Act
        final result = parseValueByInputDataType(
          type: InputDataType.phone,
          value: raw,
        );

        // Assert
        expect(result, '+14155552671');
      });

      test('should collapse existing plus signs into one prefix', () {
        // Arrange
        const raw = '++44 20 7946 0958';

        // Act
        final result = parseValueByInputDataType(
          type: InputDataType.phone,
          value: raw,
        );

        // Assert
        expect(result, '+442079460958');
      });

      test('should return null when there are no digits', () {
        // Arrange
        const raw = '+()- ';

        // Act
        final result = parseValueByInputDataType(
          type: InputDataType.phone,
          value: raw,
        );

        // Assert
        expect(result, isNull);
      });
    });

    group('numbers', () {
      test('should parse an integer value', () {
        // Arrange & Act
        final result = parseValueByInputDataType(
          type: InputDataType.int,
          value: '42',
        );

        // Assert
        expect(result, 42);
      });

      test('should parse a double value', () {
        // Arrange & Act
        final result = parseValueByInputDataType(
          type: InputDataType.double,
          value: '3.14',
        );

        // Assert
        expect(result, 3.14);
      });
    });

    test('should return null for a null value', () {
      // Arrange & Act
      final result = parseValueByInputDataType(
        type: InputDataType.phone,
        value: null,
      );

      // Assert
      expect(result, isNull);
    });
  });

  group('InputData time field', () {
    testWidgets('should render a selected time with the shared formatter', (
      tester,
    ) async {
      // Arrange
      const time = TimeOfDay(hour: 14, minute: 30);
      final expected = DateFormat.jm().format(DateTime(1, 1, 1, 14, 30));

      // Act
      await tester.pumpWidget(
        _wrap(const InputData(value: time, type: InputDataType.time)),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('should dispose cleanly when removed from the tree', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        _wrap(
          const InputData(
            value: TimeOfDay(hour: 9, minute: 0),
            type: InputDataType.time,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
    });
  });
}
