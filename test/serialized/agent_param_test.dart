import 'package:fabric_flutter/serialized/agent_param.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentParam', () {
    group('fromJson', () {
      test('should deserialize every field', () {
        // Arrange
        final json = <String, dynamic>{
          'name': 'route',
          'type': 'boolean',
          'required': true,
          'enum': ['a', 'b'],
          'description': 'Route to open',
        };

        // Act
        final param = AgentParam.fromJson(json);

        // Assert
        expect(param.name, 'route');
        expect(param.type, AgentParamType.boolean);
        expect(param.required, isTrue);
        expect(param.enumValues, ['a', 'b']);
        expect(param.description, 'Route to open');
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final param = AgentParam.fromJson(null);

        // Assert
        expect(param.name, '');
        expect(param.type, AgentParamType.string);
        expect(param.required, isFalse);
        expect(param.enumValues, isNull);
      });
    });

    group('toJson', () {
      test('should emit the JSON Schema enum keyword', () {
        // Arrange
        final param = AgentParam(name: 'mode', enumValues: const ['on', 'off']);

        // Act
        final json = param.toJson();

        // Assert
        expect(json['enum'], ['on', 'off']);
        expect(json['type'], 'string');
      });

      test('should round-trip without losing data', () {
        // Arrange
        final param = AgentParam(
          name: 'count',
          type: AgentParamType.integer,
          required: true,
          description: 'How many',
        );

        // Act
        final restored = AgentParam.fromJson(
          AgentParam.fromJson(param.toJson()).toJson(),
        );

        // Assert
        expect(restored.name, 'count');
        expect(restored.type, AgentParamType.integer);
        expect(restored.required, isTrue);
        expect(restored.description, 'How many');
      });
    });
  });
}
