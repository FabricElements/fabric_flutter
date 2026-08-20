import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/helper/filter_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilterHelper.valueFromType', () {
    test('should return the value unchanged when it is null', () {
      // Arrange, Act & Assert
      expect(
        FilterHelper.valueFromType(
          dataType: InputDataType.date,
          sqlQueryType: SQLQueryType.sql,
          value: null,
        ),
        isNull,
      );
    });

    test('should serialize a date value as a quoted UTC yyyy-MM-dd string', () {
      // Arrange
      final date = DateTime.utc(2024, 3, 7, 18, 45);

      // Act
      final result = FilterHelper.valueFromType(
        dataType: InputDataType.date,
        sqlQueryType: SQLQueryType.sql,
        value: date,
      );

      // Assert
      expect(result, '"2024-03-07"');
    });

    test('should drop time-of-day information from the serialized date', () {
      // Arrange — a late-day timestamp must still format to its calendar date.
      final date = DateTime.utc(2024, 12, 31, 23, 59, 59);

      // Act
      final result = FilterHelper.valueFromType(
        dataType: InputDataType.date,
        sqlQueryType: SQLQueryType.sql,
        value: date,
      );

      // Assert
      expect(result, '"2024-12-31"');
    });
  });
}
