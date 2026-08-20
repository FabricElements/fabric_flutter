import 'package:fabric_flutter/serialized/agent_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentError', () {
    group('fromJson', () {
      test('should deserialize the snake_case wire code', () {
        // Arrange
        final json = <String, dynamic>{
          'code': 'invalid_params',
          'message': 'Parameter "route" is required.',
        };

        // Act
        final error = AgentError.fromJson(json);

        // Assert
        expect(error.code, AgentErrorCode.invalidParams);
        expect(error.message, 'Parameter "route" is required.');
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final error = AgentError.fromJson(null);

        // Assert
        expect(error.code, AgentErrorCode.failed);
        expect(error.message, '');
      });
    });

    group('toJson', () {
      test('should emit snake_case codes for every value', () {
        // Arrange
        const codes = <AgentErrorCode, String>{
          AgentErrorCode.unauthorized: 'unauthorized',
          AgentErrorCode.notFound: 'not_found',
          AgentErrorCode.invalidParams: 'invalid_params',
          AgentErrorCode.disabled: 'disabled',
          AgentErrorCode.failed: 'failed',
        };

        // Act
        final emitted = codes.keys.map(
          (code) => AgentError(code: code, message: '').toJson()['code'],
        );

        // Assert
        expect(emitted, codes.values);
      });
    });
  });
}
