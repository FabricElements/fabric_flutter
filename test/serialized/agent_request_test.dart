import 'package:fabric_flutter/serialized/agent_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentRequest', () {
    group('fromJson', () {
      test('should deserialize a decoded transport frame', () {
        // Arrange
        final json = <String, dynamic>{
          'id': '1',
          'method': 'invoke',
          'params': {'commandId': 'tap'},
        };

        // Act
        final request = AgentRequest.fromJson(json);

        // Assert
        expect(request.id, '1');
        expect(request.method, 'invoke');
        expect(request.params?['commandId'], 'tap');
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final request = AgentRequest.fromJson(null);

        // Assert
        expect(request.id, '');
        expect(request.method, '');
        expect(request.params, isNull);
      });
    });

    group('toJson', () {
      test('should round-trip without losing data', () {
        // Arrange
        final request = AgentRequest(
          id: '7',
          method: 'state',
          params: const {'scope': 'screen'},
        );

        // Act
        final restored = AgentRequest.fromJson(
          AgentRequest.fromJson(request.toJson()).toJson(),
        );

        // Assert
        expect(restored.id, '7');
        expect(restored.method, 'state');
        expect(restored.params?['scope'], 'screen');
      });
    });
  });
}
