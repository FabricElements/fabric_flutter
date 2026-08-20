import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:fabric_flutter/serialized/agent_state_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentStateResult', () {
    group('fromJson', () {
      test('should deserialize the route and its elements', () {
        // Arrange
        final json = <String, dynamic>{
          'route': '/orders',
          'path': '/orders',
          'params': {'id': '42'},
          'elements': [
            {'id': 'orders_list_button_refresh', 'type': 'button'},
          ],
        };

        // Act
        final result = AgentStateResult.fromJson(json);

        // Assert
        expect(result.route, '/orders');
        expect(result.path, '/orders');
        expect(result.params['id'], '42');
        expect(result.elements.single.type, AgentElementType.button);
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final result = AgentStateResult.fromJson(null);

        // Assert
        expect(result.route, isNull);
        expect(result.path, isNull);
        expect(result.params, isEmpty);
        expect(result.elements, isEmpty);
      });
    });

    group('toJson', () {
      test('should round-trip without losing data', () {
        // Arrange
        final result = AgentStateResult(
          route: '/profile',
          path: '/profile',
          elements: [
            AgentElementSnapshot(
              id: 'profile_form_input_email',
              type: AgentElementType.textInput,
              value: 'user@example.com',
            ),
          ],
        );

        // Act
        final restored = AgentStateResult.fromJson(
          AgentStateResult.fromJson(result.toJson()).toJson(),
        );

        // Assert
        expect(restored.route, '/profile');
        expect(restored.elements.single.id, 'profile_form_input_email');
        expect(restored.elements.single.value, 'user@example.com');
      });
    });
  });
}
