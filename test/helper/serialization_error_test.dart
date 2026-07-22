import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:fabric_flutter/helper/serialization_error.dart';

void main() {
  group('serializationError', () {
    group('CheckedFromJsonException', () {
      test('should name the offending key and include the detail', () {
        // Arrange
        final error = CheckedFromJsonException(
          <String, dynamic>{'id': null},
          'id',
          'UserData',
          "type 'Null' is not a subtype of type 'String'",
        );

        // Act
        final message = serializationError(error);

        // Assert
        expect(
          message,
          'Invalid field "id": '
              "type 'Null' is not a subtype of type 'String'",
        );
      });

      test('should fall back to the class name when the key is null', () {
        // Arrange
        final error = CheckedFromJsonException(
          <String, dynamic>{},
          null,
          'UserData',
          'missing required field',
        );

        // Act
        final message = serializationError(error);

        // Assert
        expect(message, 'Invalid `UserData`: missing required field');
      });

      test('should omit the detail when the message is null', () {
        // Arrange
        final error = CheckedFromJsonException(
          <String, dynamic>{'id': null},
          'id',
          'UserData',
          null,
        );

        // Act
        final message = serializationError(error);

        // Assert
        expect(message, 'Invalid field "id"');
      });

      test('should omit the detail when the message is empty', () {
        // Arrange
        final error = CheckedFromJsonException(
          <String, dynamic>{'id': null},
          'id',
          'UserData',
          '',
        );

        // Act
        final message = serializationError(error);

        // Assert
        expect(message, 'Invalid field "id"');
      });
    });

    group('generic errors', () {
      test('should return the string representation of a plain error', () {
        // Arrange
        final error = FormatException('unexpected token');

        // Act
        final message = serializationError(error);

        // Assert
        expect(message, error.toString());
      });

      test('should return the string representation of a String error', () {
        // Arrange
        const error = 'error--500';

        // Act
        final message = serializationError(error);

        // Assert
        expect(message, 'error--500');
      });
    });
  });
}
