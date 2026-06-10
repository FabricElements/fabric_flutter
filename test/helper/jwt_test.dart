import 'dart:convert';

import 'package:fabric_flutter/helper/jwt.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a JWT-like token whose payload is the base64url encoding of [payload].
///
/// The padding characters are stripped to exercise the helper's re-padding
/// logic, mirroring how real JWT payloads are transmitted.
String buildToken(String payload) {
  final encoded = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
  return 'header.$encoded.signature';
}

void main() {
  group('parseJwt', () {
    test('should decode the payload of a valid token into a map', () {
      // Arrange
      final token = buildToken('{"sub":"1234567890","name":"John Doe"}');

      // Act
      final payload = parseJwt(token);

      // Assert
      expect(payload['sub'], '1234567890');
      expect(payload['name'], 'John Doe');
    });

    test('should decode a payload that requires re-padding', () {
      // Arrange - this JSON encodes to a length that needs padding restored.
      final token = buildToken('{"a":1}');

      // Act
      final payload = parseJwt(token);

      // Assert
      expect(payload['a'], 1);
    });

    test('should throw when the token does not have three parts', () {
      // Arrange
      const token = 'only.two';

      // Act & Assert
      expect(() => parseJwt(token), throwsA(isA<Exception>()));
    });

    test('should throw when the decoded payload is not a JSON object', () {
      // Arrange - payload decodes to the number 123, not a map.
      final token = buildToken('123');

      // Act & Assert
      expect(() => parseJwt(token), throwsA(isA<Exception>()));
    });
  });
}
