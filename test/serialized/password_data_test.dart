import 'package:fabric_flutter/serialized/password_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordData', () {
    group('fromJson', () {
      test('should deserialize current and new passwords', () {
        // Arrange
        final json = <String, dynamic>{
          'currentPassword': 'old-secret',
          'newPassword': 'new-secret',
        };

        // Act
        final data = PasswordData.fromJson(json);

        // Assert
        expect(data.currentPassword, 'old-secret');
        expect(data.newPassword, 'new-secret');
      });
    });

    group('toJson', () {
      test('should serialize both password fields', () {
        // Arrange
        final data = PasswordData(
          currentPassword: 'a',
          newPassword: 'b',
        );

        // Act
        final json = data.toJson();

        // Assert
        expect(json, {'currentPassword': 'a', 'newPassword': 'b'});
      });

      test('should round-trip values through fromJson', () {
        // Arrange
        final original = PasswordData(
          currentPassword: 'currentPass1!',
          newPassword: 'newPass2!',
        );

        // Act
        final restored = PasswordData.fromJson(original.toJson());

        // Assert
        expect(restored.currentPassword, original.currentPassword);
        expect(restored.newPassword, original.newPassword);
      });
    });
  });
}
