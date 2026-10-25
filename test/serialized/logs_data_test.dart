import 'package:fabric_flutter/serialized/logs_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogsData', () {
    group('fromJson', () {
      test('should tolerate a null payload', () {
        // Arrange & Act
        final data = LogsData.fromJson(null);

        // Assert
        expect(data, isA<LogsData>());
      });

      test('should tolerate an empty map', () {
        // Arrange & Act
        final data = LogsData.fromJson({});

        // Assert
        expect(data, isA<LogsData>());
        expect(data.id, isNull);
        expect(data.text, isNull);
        expect(data.timestamp, isNull);
      });

      test('should deserialize all fields from a full payload', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'log-001',
          'text': 'Something happened.',
          'timestamp': '2021-11-09T20:23:27',
          'data': {'key': 'value', 'count': 3},
        };

        // Act
        final data = LogsData.fromJson(json);

        // Assert
        expect(data.id, 'log-001');
        expect(data.text, 'Something happened.');
        expect(data.timestamp, isA<DateTime>());
        expect(data.timestamp!.year, 2021);
        expect(data.data, isNotNull);
        expect(data.data!['key'], 'value');
      });

      test('should parse timestamp via Utils.dateTimeFromJson', () {
        // Arrange
        final json = <String, dynamic>{'timestamp': '2023-06-15T08:30:00.000Z'};

        // Act
        final data = LogsData.fromJson(json);

        // Assert — stored as UTC
        expect(data.timestamp!.isUtc, isTrue);
        expect(data.timestamp!.year, 2023);
        expect(data.timestamp!.month, 6);
        expect(data.timestamp!.day, 15);
      });

      test('should return null timestamp when value is absent', () {
        // Arrange & Act
        final data = LogsData.fromJson({'id': 'x'});

        // Assert
        expect(data.timestamp, isNull);
      });

      test('should accept an integer id', () {
        // Arrange
        final json = <String, dynamic>{'id': 42};

        // Act
        final data = LogsData.fromJson(json);

        // Assert
        expect(data.id, 42);
      });

      test('child field is excluded from JSON deserialization', () {
        // Arrange
        final json = <String, dynamic>{'id': 'w', 'child': 'ignored'};

        // Act — child JSON key is ignored; child field stays null
        final data = LogsData.fromJson(json);

        // Assert
        expect(data.child, isNull);
      });
    });

    group('toJson', () {
      test('should serialize id and text', () {
        // Arrange
        final data = LogsData(id: 'log-1', text: 'hello');

        // Act
        final json = data.toJson();

        // Assert
        expect(json['id'], 'log-1');
        expect(json['text'], 'hello');
      });

      test('should omit timestamp when null (includeIfNull: false)', () {
        // Arrange
        final data = LogsData(id: 'x');

        // Act
        final json = data.toJson();

        // Assert
        expect(json.containsKey('timestamp'), isFalse);
      });

      test(
        'should serialize timestamp as yyyy-MM-dd date string via Utils.dateToJson',
        () {
          // Arrange
          final dt = DateTime.utc(2024, 4, 22, 14, 0, 0);
          final data = LogsData(timestamp: dt);

          // Act
          final json = data.toJson();

          // Assert — Utils.dateToJson outputs yyyy-MM-dd only
          expect(json['timestamp'], '2024-04-22');
        },
      );

      test('should exclude child widget from JSON output', () {
        // Arrange
        final data = LogsData(id: 'w', child: const Text('ignored'));

        // Act
        final json = data.toJson();

        // Assert
        expect(json.containsKey('child'), isFalse);
      });
    });

    group('fromJson / toJson round-trip', () {
      test('should preserve id and text across a round-trip', () {
        // Arrange — omit data field: LogsData.data is Map<dynamic, dynamic>
        // but fromJson casts it to Map<String, dynamic>? which works only when
        // keys are already strings (the generated code uses (json['data'] as Map?))
        final original = LogsData(id: 'round', text: 'A log message.');

        // Act
        final restored = LogsData.fromJson(original.toJson());

        // Assert
        expect(restored.id, original.id);
        expect(restored.text, original.text);
      });

      test('should preserve timestamp date across a round-trip', () {
        // Arrange — dateToJson keeps only yyyy-MM-dd, so time is lost
        final dt = DateTime.utc(2023, 10, 5, 8, 0, 0);
        final original = LogsData(timestamp: dt);

        // Act
        final json = original.toJson();
        final restored = LogsData.fromJson(json);

        // Assert — year/month/day survive the trip; time-of-day is not preserved
        expect(restored.timestamp!.year, 2023);
        expect(restored.timestamp!.month, 10);
        expect(restored.timestamp!.day, 5);
      });
    });
  });
}
