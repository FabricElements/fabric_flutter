import 'package:fabric_flutter/serialized/agent_command_info.dart';
import 'package:fabric_flutter/serialized/agent_param.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentCommandInfo', () {
    group('fromJson', () {
      test('should deserialize nested params and the required role', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'archive_order',
          'title': 'Archive order',
          'description': 'Archives an order',
          'category': 'orders',
          'params': [
            {'name': 'orderId', 'required': true},
          ],
          'requiresRole': 'admin',
        };

        // Act
        final info = AgentCommandInfo.fromJson(json);

        // Assert
        expect(info.id, 'archive_order');
        expect(info.category, 'orders');
        expect(info.params.single.name, 'orderId');
        expect(info.params.single.required, isTrue);
        expect(info.requiresRole, 'admin');
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final info = AgentCommandInfo.fromJson(null);

        // Assert
        expect(info.id, '');
        expect(info.title, '');
        expect(info.category, 'general');
        expect(info.params, isEmpty);
        expect(info.requiresRole, isNull);
      });
    });

    group('toJson', () {
      test('should round-trip without losing data', () {
        // Arrange
        final info = AgentCommandInfo(
          id: 'tap',
          title: 'Tap',
          category: 'interaction',
          params: [AgentParam(name: 'elementId', required: true)],
          requiresRole: 'operator',
        );

        // Act
        final restored = AgentCommandInfo.fromJson(
          AgentCommandInfo.fromJson(info.toJson()).toJson(),
        );

        // Assert
        expect(restored.id, 'tap');
        expect(restored.category, 'interaction');
        expect(restored.params.single.name, 'elementId');
        expect(restored.requiresRole, 'operator');
      });
    });
  });
}
