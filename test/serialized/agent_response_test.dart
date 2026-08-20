import 'package:fabric_flutter/serialized/agent_error.dart';
import 'package:fabric_flutter/serialized/agent_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentResponse', () {
    group('success', () {
      test('should mark the response as ok and carry no error', () {
        // Arrange & Act
        final response = AgentResponse.success(
          id: '1',
          result: const {'pong': true},
        );

        // Assert
        expect(response.ok, isTrue);
        expect(response.error, isNull);
        expect(response.toJson()['result'], const {'pong': true});
      });
    });

    group('failure', () {
      test('should mark the response as failed and carry the error', () {
        // Arrange
        final error = AgentError(
          code: AgentErrorCode.notFound,
          message: 'missing',
        );

        // Act
        final json = AgentResponse.failure(id: '2', error: error).toJson();

        // Assert
        expect(json['ok'], isFalse);
        expect(json['result'], isNull);
        expect((json['error'] as Map)['code'], 'not_found');
      });
    });

    group('fromJson', () {
      test('should tolerate a null payload', () {
        // Arrange & Act
        final response = AgentResponse.fromJson(null);

        // Assert
        expect(response.id, '');
        expect(response.ok, isFalse);
        expect(response.result, isNull);
        expect(response.error, isNull);
      });

      test('should round-trip a failure without losing data', () {
        // Arrange
        final response = AgentResponse.failure(
          id: '3',
          error: AgentError(
            code: AgentErrorCode.disabled,
            message: 'bridge off',
          ),
        );

        // Act
        final restored = AgentResponse.fromJson(
          AgentResponse.fromJson(response.toJson()).toJson(),
        );

        // Assert
        expect(restored.id, '3');
        expect(restored.ok, isFalse);
        expect(restored.error?.code, AgentErrorCode.disabled);
        expect(restored.error?.message, 'bridge off');
      });
    });
  });
}
