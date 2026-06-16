import 'package:fabric_flutter/helper/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Utils.createCryptoRandomString', () {
    test('should return exactly the requested length (default 32)', () {
      // Arrange & Act
      final result = Utils.createCryptoRandomString();

      // Assert
      expect(result.length, 32);
    });

    test('should return exactly the requested length when specified', () {
      // Arrange & Act
      final result8 = Utils.createCryptoRandomString(8);
      final result16 = Utils.createCryptoRandomString(16);
      final result64 = Utils.createCryptoRandomString(64);

      // Assert
      expect(result8.length, 8);
      expect(result16.length, 16);
      expect(result64.length, 64);
    });

    test('should only contain valid base64url characters', () {
      // Arrange
      final base64urlPattern = RegExp(r'^[A-Za-z0-9+/\-_]+$');

      // Act
      final result = Utils.createCryptoRandomString(64);

      // Assert
      expect(base64urlPattern.hasMatch(result), isTrue);
    });

    test('should produce distinct values across calls', () {
      // Arrange & Act – collisions are astronomically unlikely for 32-char output.
      final a = Utils.createCryptoRandomString();
      final b = Utils.createCryptoRandomString();

      // Assert
      expect(a, isNot(equals(b)));
    });
  });
}
