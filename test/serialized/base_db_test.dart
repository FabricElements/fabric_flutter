import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/serialized/base_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';

import '../support/firebase_test_harness.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTest();
  });

  group('BaseFirestore', () {
    group('fromJson', () {
      test('should throw when id is missing from a null payload', () {
        // Arrange & Act & Assert — id is @JsonKey(required: true); null input becomes {} which lacks id
        expect(
          () => BaseFirestore.fromJson(null),
          throwsA(isA<MissingRequiredKeysException>()),
        );
      });

      test('should throw when id is missing from an empty map', () {
        // Arrange & Act & Assert
        expect(
          () => BaseFirestore.fromJson({}),
          throwsA(isA<MissingRequiredKeysException>()),
        );
      });

      test('should deserialize id field', () {
        // Arrange
        final json = <String, dynamic>{'id': 'doc123'};

        // Act
        final data = BaseFirestore.fromJson(json);

        // Assert
        expect(data.id, 'doc123');
      });

      test('should deserialize backup as false when absent', () {
        // Arrange
        final json = <String, dynamic>{'id': 'abc'};

        // Act
        final data = BaseFirestore.fromJson(json);

        // Assert
        expect(data.backup, isFalse);
      });

      test('should deserialize an ISO 8601 created timestamp', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'doc1',
          'created': '2024-01-15T10:00:00.000Z',
        };

        // Act
        final data = BaseFirestore.fromJson(json);

        // Assert
        expect(data.created, isA<DateTime>());
        expect(data.created!.year, 2024);
        expect(data.created!.month, 1);
        expect(data.created!.day, 15);
      });

      test('should deserialize a Timestamp object for created', () {
        // Arrange
        final ts = Timestamp.fromDate(DateTime.utc(2023, 6, 1));
        final json = <String, dynamic>{'id': 'doc2', 'created': ts};

        // Act
        final data = BaseFirestore.fromJson(json);

        // Assert
        expect(data.created!.year, 2023);
        expect(data.created!.month, 6);
        expect(data.created!.day, 1);
      });

      test('should deserialize an ISO 8601 updated timestamp', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'doc1',
          'updated': '2024-03-20T12:30:00.000Z',
        };

        // Act
        final data = BaseFirestore.fromJson(json);

        // Assert
        expect(data.updated, isA<DateTime>());
        expect(data.updated!.year, 2024);
        expect(data.updated!.month, 3);
      });

      test('should fall back to now when updated is null', () {
        // Arrange — timestampFromJsonDefault falls back to DateTime.now()
        final before = DateTime.now().subtract(const Duration(seconds: 5));
        final json = <String, dynamic>{'id': 'fallback'};

        // Act
        final data = BaseFirestore.fromJson(json);

        // Assert
        expect(data.updated, isA<DateTime>());
        expect(data.updated!.isAfter(before), isTrue);
      });
    });

    group('toJson', () {
      test('should include id and backup fields', () {
        // Arrange
        final data = BaseFirestore(id: 'abc');

        // Act
        final json = data.toJson();

        // Assert
        expect(json['id'], 'abc');
        expect(json['backup'], false);
      });

      test('should always serialize backup as false via Utils.boolFalse', () {
        // Arrange — boolFalse ignores the stored value and always returns false
        final data = BaseFirestore(id: 'x', backup: true);

        // Act
        final json = data.toJson();

        // Assert — Utils.boolFalse always emits false
        expect(json['backup'], false);
      });

      test(
        'should serialize updated as a Timestamp (timestampUpdate returns now)',
        () {
          // Arrange
          final data = BaseFirestore(id: 'upd', updated: DateTime.utc(2022, 1));

          // Act
          final json = data.toJson();

          // Assert — timestampUpdate always returns Timestamp.now(), not the supplied value
          expect(json['updated'], isA<Timestamp>());
        },
      );

      test('should serialize created as a Timestamp', () {
        // Arrange
        final dt = DateTime.utc(2023, 5, 10);
        final data = BaseFirestore(id: 'cr', created: dt);

        // Act
        final json = data.toJson();

        // Assert
        expect(json['created'], isA<Timestamp>());
        final ts = json['created'] as Timestamp;
        expect(ts.toDate().toUtc().year, 2023);
        expect(ts.toDate().toUtc().month, 5);
        expect(ts.toDate().toUtc().day, 10);
      });
    });

    group('fromJson / toJson round-trip', () {
      test('should preserve id across a round-trip', () {
        // Arrange
        final original = BaseFirestore(id: 'round-trip-id');

        // Act
        final json = original.toJson();
        // Re-inject id since toJson includes it; round-trip via fromJson
        final restored = BaseFirestore.fromJson(json);

        // Assert
        expect(restored.id, original.id);
      });

      test('should preserve created date across a round-trip', () {
        // Arrange
        final dt = DateTime.utc(2024, 7, 4, 9, 0, 0);
        final original = BaseFirestore(id: 'r2', created: dt);

        // Act
        final json = original.toJson();
        final restored = BaseFirestore.fromJson(json);

        // Assert — created round-trips via Timestamp → DateTime; year/month/day survive
        expect(restored.created!.year, 2024);
        expect(restored.created!.month, 7);
        expect(restored.created!.day, 4);
      });
    });
  });
}
