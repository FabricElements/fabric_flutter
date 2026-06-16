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
      test('should include password when non-null (used for account creation)', () {
        // Arrange – password is only set during new-user creation flows.
        final data = UserData(
          email: 'user@example.com',
          firstName: 'Ada',
          password: 'Sup3rS3cur3!',
        );

        // Act
        final json = data.toJson();

        // Assert – the field is serialized so Cloud Functions can receive it.
        expect(json['password'], 'Sup3rS3cur3!');
      });

      test('should omit password when it is null (existing-user fetch)', () {
        // Arrange – password is always null when reading an existing user.
        final data = UserData(email: 'user@example.com');

        // Act
        final json = data.toJson();

        // Assert – includeIfNull: false keeps the key absent.
        expect(json.containsKey('password'), isFalse);
      });

      test('should include other fields alongside a non-null password', () {
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
        expect(json['password'], 'P@ssword1');
      });
    });

    group('fromJson / toJson round-trip', () {
      test('should preserve all fields across a round-trip', () {
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

      test('should preserve a non-null password across a round-trip', () {
        // Arrange – simulates account-creation payload being re-read.
        final original = UserData(password: 'R0undTrip!');

        // Act
        final restored = UserData.fromJson(original.toJson());

        // Assert
        expect(restored.password, 'R0undTrip!');
      });
    });
  });
}
