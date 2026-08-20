import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_exception.dart';
import 'package:fabric_flutter/helper/agent/agent_registry.dart';
import 'package:fabric_flutter/serialized/agent_error.dart';
import 'package:fabric_flutter/serialized/agent_param.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a throwaway command used to exercise the registry.
AgentCommand _command(String id, {String category = 'general'}) =>
    AgentCommand.define(
      id: id,
      title: id,
      category: category,
      handler: (context) => null,
    );

void main() {
  group('AgentRegistry', () {
    group('register', () {
      test('should store a command and expose it by id', () {
        // Arrange
        final registry = AgentRegistry();

        // Act
        registry.register(_command('navigate'));

        // Assert
        expect(registry.contains('navigate'), isTrue);
        expect(registry.byId('navigate')?.id, 'navigate');
        expect(registry.length, 1);
      });

      test('should throw when the same id is registered twice', () {
        // Arrange
        final registry = AgentRegistry();
        registry.register(_command('navigate'));

        // Act & Assert
        expect(
          () => registry.register(_command('navigate')),
          throwsA(isA<ArgumentError>()),
        );
        expect(registry.length, 1);
      });

      test('should replace an existing command when override is true', () {
        // Arrange
        final registry = AgentRegistry();
        registry.register(_command('navigate'));

        // Act
        registry.register(
          _command('navigate', category: 'custom'),
          override: true,
        );

        // Assert
        expect(registry.length, 1);
        expect(registry.byId('navigate')?.category, 'custom');
      });

      test('should throw when the id is empty', () {
        // Arrange
        final registry = AgentRegistry();

        // Act & Assert
        expect(
          () => registry.register(_command('')),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('registerAll', () {
      test('should register every supplied command', () {
        // Arrange
        final registry = AgentRegistry();

        // Act
        registry.registerAll([_command('a'), _command('b')]);

        // Assert
        expect(registry.ids, ['a', 'b']);
      });
    });

    group('unregister', () {
      test('should remove a registered command and report success', () {
        // Arrange
        final registry = AgentRegistry();
        registry.register(_command('tap'));

        // Act
        final removed = registry.unregister('tap');

        // Assert
        expect(removed, isTrue);
        expect(registry.contains('tap'), isFalse);
      });

      test('should report failure for an unknown command', () {
        // Arrange
        final registry = AgentRegistry();

        // Act
        final removed = registry.unregister('missing');

        // Assert
        expect(removed, isFalse);
      });
    });

    group('byCategory', () {
      test('should group commands by their category', () {
        // Arrange
        final registry = AgentRegistry();
        registry.registerAll([
          _command('tap', category: 'interaction'),
          _command('set_value', category: 'interaction'),
          _command('navigate', category: 'navigation'),
        ]);

        // Act
        final grouped = registry.byCategory();

        // Assert
        expect(grouped.keys, containsAll(['interaction', 'navigation']));
        expect(grouped['interaction']?.length, 2);
        expect(registry.withCategory('navigation').single.id, 'navigate');
      });
    });

    group('catalog', () {
      test('should serialize every registered command', () {
        // Arrange
        final registry = AgentRegistry();
        registry.register(
          AgentCommand.define(
            id: 'archive',
            title: 'Archive',
            requiresRole: 'admin',
            params: [AgentParam(name: 'id', required: true)],
            handler: (context) => null,
          ),
        );

        // Act
        final json = registry.toJson();

        // Assert
        expect(json.single['id'], 'archive');
        expect(json.single['requiresRole'], 'admin');
        expect((json.single['params'] as List).single, isA<Map>());
      });
    });

    group('clear', () {
      test('should remove every registered command', () {
        // Arrange
        final registry = AgentRegistry();
        registry.registerAll([_command('a'), _command('b')]);

        // Act
        registry.clear();

        // Assert
        expect(registry.length, 0);
      });
    });
  });

  group('AgentCommand', () {
    group('validate', () {
      test('should throw when a required parameter is missing', () {
        // Arrange
        final command = AgentCommand.define(
          id: 'tap',
          title: 'Tap',
          params: [AgentParam(name: 'elementId', required: true)],
          handler: (context) => null,
        );

        // Act & Assert
        expect(
          () => command.validate(const {}),
          throwsA(
            isA<AgentException>().having(
              (error) => error.code,
              'code',
              AgentErrorCode.invalidParams,
            ),
          ),
        );
      });

      test('should throw when a value falls outside a declared enum', () {
        // Arrange
        final command = AgentCommand.define(
          id: 'wait',
          title: 'Wait',
          params: [
            AgentParam(name: 'condition', enumValues: const ['visible']),
          ],
          handler: (context) => null,
        );

        // Act & Assert
        expect(
          () => command.validate(const {'condition': 'gone'}),
          throwsA(isA<AgentException>()),
        );
      });

      test('should accept a valid parameter set', () {
        // Arrange
        final command = AgentCommand.define(
          id: 'wait',
          title: 'Wait',
          params: [
            AgentParam(name: 'condition', enumValues: const ['visible']),
            AgentParam(name: 'elementId', required: true),
          ],
          handler: (context) => null,
        );

        // Act & Assert
        expect(
          () => command.validate(const {
            'condition': 'visible',
            'elementId': 'a',
          }),
          returnsNormally,
        );
      });
    });
  });

  group('AgentCommandContext', () {
    group('require', () {
      test('should return the typed parameter when present', () {
        // Arrange
        final context = AgentCommandContext(
          commandId: 'tap',
          requestId: '1',
          params: const {'elementId': 'a'},
        );

        // Act
        final value = context.require<String>('elementId');

        // Assert
        expect(value, 'a');
      });

      test('should throw invalidParams when the parameter is missing', () {
        // Arrange
        final context = AgentCommandContext(commandId: 'tap', requestId: '1');

        // Act & Assert
        expect(
          () => context.require<String>('elementId'),
          throwsA(
            isA<AgentException>().having(
              (error) => error.code,
              'code',
              AgentErrorCode.invalidParams,
            ),
          ),
        );
      });

      test(
        'should throw invalidParams when the parameter has a wrong type',
        () {
          // Arrange
          final context = AgentCommandContext(
            commandId: 'tap',
            requestId: '1',
            params: const {'elementId': 12},
          );

          // Act & Assert
          expect(
            () => context.optional<String>('elementId'),
            throwsA(isA<AgentException>()),
          );
        },
      );
    });
  });
}
