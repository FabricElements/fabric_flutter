import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserData', () {
    group('fromJson', () {
      test('should return defaults when given a null payload', () {
        // Arrange & Act
        final data = UserData.fromJson(null);

        // Assert
        expect(data.role, 'unknown');
        expect(data.fcm, isEmpty);
        expect(data.email, isNull);
      });

      test('should deserialize basic fields from a JSON map', () {
        // Arrange
        final json = <String, dynamic>{
          'email': 'user@example.com',
          'firstName': 'Ada',
          'lastName': 'Lovelace',
          'role': 'admin',
        };

        // Act
        final data = UserData.fromJson(json);

        // Assert
        expect(data.email, 'user@example.com');
        expect(data.firstName, 'Ada');
        expect(data.lastName, 'Lovelace');
        expect(data.role, 'admin');
      });

      test('should deserialize a password value from JSON', () {
        // Arrange – the field is read on ingest so the app can act on it.
        final json = <String, dynamic>{
          'email': 'user@example.com',
          'password': 's3cr3t!',
        };

        // Act
        final data = UserData.fromJson(json);

        // Assert – value is available in memory after deserialization.
        expect(data.password, 's3cr3t!');
      });
    });

    group('toJson', () {
      test('should never include password in serialized output', () {
        // Arrange – password is provided during construction.
        final data = UserData(
          email: 'user@example.com',
          firstName: 'Ada',
          password: 'Sup3rS3cur3!',
        );

        // Act
        final json = data.toJson();

        // Assert – the sensitive field must be absent from the map.
        expect(json.containsKey('password'), isFalse);
      });

      test('should omit password even when it is non-null', () {
        // Arrange
        final data = UserData(password: 'P@ssword1');

        // Act
        final json = data.toJson();

        // Assert
        expect(json['password'], isNull);
        expect(json.containsKey('password'), isFalse);
      });

      test('should include non-sensitive fields normally', () {
        // Arrange
        final data = UserData(
          email: 'user@example.com',
          role: 'editor',
          password: 'P@ssword1',
        );

        // Act
        final json = data.toJson();

        // Assert
        expect(json['email'], 'user@example.com');
        expect(json['role'], 'editor');
        expect(json.containsKey('password'), isFalse);
      });
    });

    group('fromJson / toJson round-trip', () {
      test('should preserve non-sensitive fields across a round-trip', () {
        // Arrange
        final original = UserData(
          email: 'user@example.com',
          firstName: 'Ada',
          lastName: 'Lovelace',
          role: 'viewer',
        );

        // Act
        final restored = UserData.fromJson(original.toJson());

        // Assert
        expect(restored.email, original.email);
        expect(restored.firstName, original.firstName);
        expect(restored.lastName, original.lastName);
        expect(restored.role, original.role);
      });
    });
  });
}
