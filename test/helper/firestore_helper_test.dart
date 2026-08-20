import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/helper/firestore_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreHelper', () {
    group('timestampFromJsonMap', () {
      test('should return the same Timestamp instance', () {
        // Arrange
        final timestamp = Timestamp(1700000000, 500);

        // Act
        final result = FirestoreHelper.timestampFromJsonMap(timestamp);

        // Assert
        expect(result, same(timestamp));
      });

      test('should build a Timestamp from an Admin SDK map', () {
        // Arrange
        final json = {'_seconds': 1700000000, '_nanoseconds': 250};

        // Act
        final result = FirestoreHelper.timestampFromJsonMap(json);

        // Assert
        expect(result, isNotNull);
        expect(result!.seconds, 1700000000);
        expect(result.nanoseconds, 250);
      });

      test('should build a Timestamp from a DateTime', () {
        // Arrange
        final date = DateTime.utc(2024, 5, 17, 12);

        // Act
        final result = FirestoreHelper.timestampFromJsonMap(date);

        // Assert
        expect(result?.toDate().toUtc(), date);
      });

      test('should build a Timestamp from an ISO 8601 string', () {
        // Arrange
        const raw = '2024-05-17T12:00:00.000Z';

        // Act
        final result = FirestoreHelper.timestampFromJsonMap(raw);

        // Assert
        expect(result?.toDate().toUtc(), DateTime.utc(2024, 5, 17, 12));
      });

      test('should return null for an unparsable string', () {
        // Arrange
        const raw = 'not a date';

        // Act
        final result = FirestoreHelper.timestampFromJsonMap(raw);

        // Assert
        expect(result, isNull);
      });

      test('should return null for null input', () {
        // Arrange & Act
        final result = FirestoreHelper.timestampFromJsonMap(null);

        // Assert
        expect(result, isNull);
      });

      test('should return null for an unsupported type', () {
        // Arrange & Act
        final result = FirestoreHelper.timestampFromJsonMap(42);

        // Assert
        expect(result, isNull);
      });
    });

    group('timestampFromJsonDefault', () {
      test('should return the parsed UTC date when parsing succeeds', () {
        // Arrange
        const raw = '2024-05-17T12:00:00.000Z';

        // Act
        final result = FirestoreHelper.timestampFromJsonDefault(raw);

        // Assert
        expect(result, DateTime.utc(2024, 5, 17, 12));
        expect(result.isUtc, isTrue);
      });

      test('should fall back to the current UTC time when input is null', () {
        // Arrange
        final before = DateTime.now().toUtc();

        // Act
        final result = FirestoreHelper.timestampFromJsonDefault(null);

        // Assert
        expect(result.isUtc, isTrue);
        expect(
          result.isBefore(before.subtract(const Duration(seconds: 5))),
          isFalse,
        );
      });
    });

    group('timestampFromJson', () {
      test('should return a UTC DateTime when parsing succeeds', () {
        // Arrange
        final timestamp = Timestamp.fromDate(DateTime.utc(2020, 1, 2, 3));

        // Act
        final result = FirestoreHelper.timestampFromJson(timestamp);

        // Assert
        expect(result, DateTime.utc(2020, 1, 2, 3));
        expect(result!.isUtc, isTrue);
      });

      test('should return null when parsing fails', () {
        // Arrange & Act
        final result = FirestoreHelper.timestampFromJson('nope');

        // Assert
        expect(result, isNull);
      });
    });

    group('timestampToJsonDefault', () {
      test('should convert a local DateTime to a UTC Timestamp', () {
        // Arrange
        final date = DateTime.utc(2021, 6, 1, 8).toLocal();

        // Act
        final result = FirestoreHelper.timestampToJsonDefault(date);

        // Assert
        expect(result.toDate().toUtc(), DateTime.utc(2021, 6, 1, 8));
      });

      test('should fall back to the current time when null', () {
        // Arrange & Act
        final result = FirestoreHelper.timestampToJsonDefault(null);

        // Assert
        expect(result, isA<Timestamp>());
      });
    });

    group('timestampToJson', () {
      test('should convert a DateTime to a UTC Timestamp', () {
        // Arrange
        final date = DateTime.utc(2022, 2, 2);

        // Act
        final result = FirestoreHelper.timestampToJson(date);

        // Assert
        expect(result?.toDate().toUtc(), date);
      });

      test('should return null when the date is null', () {
        // Arrange & Act
        final result = FirestoreHelper.timestampToJson(null);

        // Assert
        expect(result, isNull);
      });
    });

    group('timestampUpdate', () {
      test('should ignore the supplied value and return the current time', () {
        // Arrange
        final date = DateTime.utc(1999, 1, 1);

        // Act
        final result = FirestoreHelper.timestampUpdate(date);

        // Assert
        expect(result, isA<Timestamp>());
        expect(result!.toDate().year, greaterThan(2000));
      });

      test('should still return a timestamp for a null value', () {
        // Arrange & Act
        final result = FirestoreHelper.timestampUpdate(null);

        // Assert
        expect(result, isA<Timestamp>());
      });
    });

    group('notNullToJson', () {
      test('should return the value unchanged when it is not null', () {
        // Arrange & Act
        final result = FirestoreHelper.notNullToJson('value');

        // Assert
        expect(result, 'value');
      });

      test('should return a delete sentinel for null', () {
        // Arrange & Act
        final result = FirestoreHelper.notNullToJson(null);

        // Assert
        expect(result, FieldValue.delete());
      });

      test('should preserve falsy but non-null values', () {
        // Arrange & Act
        final zero = FirestoreHelper.notNullToJson(0);
        final empty = FirestoreHelper.notNullToJson('');
        final off = FirestoreHelper.notNullToJson(false);

        // Assert
        expect(zero, 0);
        expect(empty, '');
        expect(off, false);
      });
    });

    group('ignoreFieldValue', () {
      test('should return null for a FieldValue sentinel', () {
        // Arrange & Act
        final result = FirestoreHelper.ignoreFieldValue(FieldValue.delete());

        // Assert
        expect(result, isNull);
      });

      test('should return other values unchanged', () {
        // Arrange & Act
        final result = FirestoreHelper.ignoreFieldValue({'a': 1});

        // Assert
        expect(result, {'a': 1});
      });
    });
  });
}
