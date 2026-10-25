import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/serialized/filter_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilterOperator', () {
    test('should contain all expected enum values', () {
      // Arrange & Act
      const values = FilterOperator.values;

      // Assert
      expect(values, contains(FilterOperator.equal));
      expect(values, contains(FilterOperator.notEqual));
      expect(values, contains(FilterOperator.contains));
      expect(values, contains(FilterOperator.greaterThan));
      expect(values, contains(FilterOperator.greaterThanOrEqual));
      expect(values, contains(FilterOperator.lessThan));
      expect(values, contains(FilterOperator.lessThanOrEqual));
      expect(values, contains(FilterOperator.between));
      expect(values, contains(FilterOperator.any));
      expect(values, contains(FilterOperator.sort));
      expect(values, contains(FilterOperator.whereIn));
    });
  });

  group('FilterOrder', () {
    test('should contain asc and desc values', () {
      // Arrange & Act
      const values = FilterOrder.values;

      // Assert
      expect(values, contains(FilterOrder.asc));
      expect(values, contains(FilterOrder.desc));
    });
  });

  group('FilterData', () {
    group('constructor defaults', () {
      test('should use sensible defaults when no optional args given', () {
        // Arrange & Act
        final filter = FilterData(id: 'field1');

        // Assert
        expect(filter.id, 'field1');
        expect(filter.label, 'Unknown');
        expect(filter.type, InputDataType.string);
        expect(filter.enums, isEmpty);
        expect(filter.options, isEmpty);
        expect(filter.index, 0);
        expect(filter.operator, isNull);
        expect(filter.value, isNull);
      });
    });

    group('fromJson', () {
      test('should throw when id is missing from a null payload', () {
        // Arrange & Act & Assert — id is non-nullable; null becomes {} which omits id
        expect(() => FilterData.fromJson(null), throwsA(isA<TypeError>()));
      });

      test('should throw when id is missing from an empty map', () {
        // Arrange & Act & Assert
        expect(() => FilterData.fromJson({}), throwsA(isA<TypeError>()));
      });

      test('should deserialize id, type, operator, and index', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'name',
          'type': 'string',
          'operator': 'equal',
          'value': 'Alice',
          'index': 2,
        };

        // Act
        final filter = FilterData.fromJson(json);

        // Assert
        expect(filter.id, 'name');
        expect(filter.type, InputDataType.string);
        expect(filter.operator, FilterOperator.equal);
        expect(filter.value, 'Alice');
        expect(filter.index, 2);
      });

      test('should convert a date string value for date type', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'dob',
          'type': 'date',
          'operator': 'equal',
          'value': '2023-03-10T00:00:00.000Z',
        };

        // Act
        final filter = FilterData.fromJson(json);

        // Assert — value is parsed into a DateTime
        expect(filter.value, isA<DateTime>());
        expect((filter.value as DateTime).year, 2023);
        expect((filter.value as DateTime).month, 3);
        expect((filter.value as DateTime).day, 10);
      });

      test(
        'should convert between date strings into DateTime list for date + between',
        () {
          // Arrange
          final json = <String, dynamic>{
            'id': 'range',
            'type': 'date',
            'operator': 'between',
            'value': ['2023-01-01T00:00:00.000Z', '2023-12-31T00:00:00.000Z'],
          };

          // Act
          final filter = FilterData.fromJson(json);

          // Assert
          expect(filter.value, isA<List>());
          final list = filter.value as List;
          expect(list[0], isA<DateTime>());
          expect((list[0] as DateTime).year, 2023);
          expect((list[0] as DateTime).month, 1);
          expect(list[1], isA<DateTime>());
          expect((list[1] as DateTime).month, 12);
        },
      );

      test('should leave string value as-is for string type', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'query',
          'type': 'string',
          'operator': 'contains',
          'value': 'flutter',
        };

        // Act
        final filter = FilterData.fromJson(json);

        // Assert
        expect(filter.value, 'flutter');
      });

      test('should leave a boolean value as-is', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'active',
          'type': 'bool',
          'operator': 'equal',
          'value': true,
        };

        // Act
        final filter = FilterData.fromJson(json);

        // Assert
        expect(filter.value, isTrue);
      });

      test(
        'should exclude label, enums, options, and onChange from JSON deserialization',
        () {
          // Arrange
          final json = <String, dynamic>{
            'id': 'x',
            'label': 'Ignored',
            'enums': ['a', 'b'],
          };

          // Act
          final filter = FilterData.fromJson(json);

          // Assert — those fields are excluded from JSON
          expect(filter.label, 'Unknown'); // default, not from JSON
          expect(filter.enums, isEmpty);
        },
      );
    });

    group('toJson', () {
      test('should include id, type, operator, and index', () {
        // Arrange
        final filter = FilterData(
          id: 'score',
          type: InputDataType.int,
          operator: FilterOperator.greaterThan,
          value: 50,
          index: 1,
        );

        // Act
        final json = filter.toJson();

        // Assert
        expect(json['id'], 'score');
        expect(json['type'], 'int');
        expect(json['operator'], 'greaterThan');
        expect(json['index'], 1);
      });

      test('should serialize a string value as-is', () {
        // Arrange
        final filter = FilterData(
          id: 'name',
          type: InputDataType.string,
          operator: FilterOperator.equal,
          value: 'Bob',
        );

        // Act
        final json = filter.toJson();

        // Assert
        expect(json['value'], 'Bob');
      });

      test('should serialize a bool value directly', () {
        // Arrange
        final filter = FilterData(
          id: 'active',
          type: InputDataType.bool,
          operator: FilterOperator.equal,
          value: true,
        );

        // Act
        final json = filter.toJson();

        // Assert
        expect(json['value'], isTrue);
      });

      test('should serialize a date value as ISO 8601 string', () {
        // Arrange
        final dt = DateTime.utc(2024, 6, 15);
        final filter = FilterData(
          id: 'date_field',
          type: InputDataType.date,
          operator: FilterOperator.equal,
          value: dt,
        );

        // Act
        final json = filter.toJson();

        // Assert
        expect(json['value'], isA<String>());
        expect((json['value'] as String).startsWith('2024-06-15'), isTrue);
      });

      test('should serialize a date between range as ISO 8601 string list', () {
        // Arrange
        final start = DateTime.utc(2024, 1, 1);
        final end = DateTime.utc(2024, 12, 31);
        final filter = FilterData(
          id: 'range',
          type: InputDataType.date,
          operator: FilterOperator.between,
          value: [start, end],
        );

        // Act
        final json = filter.toJson();

        // Assert
        expect(json['value'], isA<List>());
        final list = json['value'] as List;
        expect((list[0] as String).startsWith('2024-01-01'), isTrue);
        expect((list[1] as String).startsWith('2024-12-31'), isTrue);
      });

      test('should serialize a sort filter as [field, direction] list', () {
        // Arrange
        final filter = FilterData(
          id: 'sort',
          type: InputDataType.string,
          operator: FilterOperator.sort,
          value: ['name', 'asc'],
        );

        // Act
        final json = filter.toJson();

        // Assert
        expect(json['value'], isA<List>());
        final list = json['value'] as List;
        expect(list[0], 'name');
        expect(list[1], 'asc');
      });

      test('should produce null value for a null sort filter', () {
        // Arrange — sort filter with a null value in the list should give null
        final filter = FilterData(
          id: 'sort',
          type: InputDataType.string,
          operator: FilterOperator.sort,
          value: [null, null],
        );

        // Act
        final json = filter.toJson();

        // Assert
        expect(json['value'], isNull);
      });

      test(
        'should exclude label, enums, options, onChange from JSON output',
        () {
          // Arrange
          final filter = FilterData(id: 'x', label: 'My Label');

          // Act
          final json = filter.toJson();

          // Assert
          expect(json.containsKey('label'), isFalse);
          expect(json.containsKey('enums'), isFalse);
          expect(json.containsKey('options'), isFalse);
          expect(json.containsKey('onChange'), isFalse);
        },
      );
    });

    group('fromJson / toJson round-trip', () {
      test('should preserve string filter across a round-trip', () {
        // Arrange
        final original = FilterData(
          id: 'username',
          type: InputDataType.string,
          operator: FilterOperator.contains,
          value: 'alice',
          index: 3,
        );

        // Act
        final restored = FilterData.fromJson(original.toJson());

        // Assert
        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.operator, original.operator);
        expect(restored.value, original.value);
        expect(restored.index, original.index);
      });

      test('should preserve date filter value across a round-trip', () {
        // Arrange
        final dt = DateTime.utc(2024, 8, 20);
        final original = FilterData(
          id: 'date_field',
          type: InputDataType.date,
          operator: FilterOperator.equal,
          value: dt,
        );

        // Act
        final restored = FilterData.fromJson(original.toJson());

        // Assert — ISO string round-trips back to UTC DateTime
        expect(restored.value, isA<DateTime>());
        expect((restored.value as DateTime).year, 2024);
        expect((restored.value as DateTime).month, 8);
        expect((restored.value as DateTime).day, 20);
      });

      test('should preserve null value filter across a round-trip', () {
        // Arrange
        final original = FilterData(id: 'f', type: InputDataType.string);

        // Act
        final restored = FilterData.fromJson(original.toJson());

        // Assert
        expect(restored.value, isNull);
        expect(restored.operator, isNull);
      });
    });

    group('clear', () {
      test('should reset index, operator, and value to defaults', () {
        // Arrange
        final filter = FilterData(
          id: 'qty',
          type: InputDataType.int,
          operator: FilterOperator.greaterThan,
          value: 10,
          index: 5,
        );

        // Act
        filter.clear();

        // Assert
        expect(filter.index, 0);
        expect(filter.operator, isNull);
        expect(filter.value, isNull);
      });

      test('should preserve id and type after clear', () {
        // Arrange
        final filter = FilterData(
          id: 'myField',
          type: InputDataType.email,
          operator: FilterOperator.equal,
          value: 'a@b.com',
        );

        // Act
        filter.clear();

        // Assert
        expect(filter.id, 'myField');
        expect(filter.type, InputDataType.email);
      });
    });
  });
}
