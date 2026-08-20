import 'package:fabric_flutter/helper/agent/agent_element.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentElementIndex', () {
    group('register', () {
      test('should index a handle and expose its snapshot', () {
        // Arrange
        final index = AgentElementIndex();
        final handle = AgentElementHandle(
          id: 'home_toolbar_button_save',
          type: AgentElementType.button,
          label: 'Save',
        );

        // Act
        index.register(handle);

        // Assert
        expect(index.contains('home_toolbar_button_save'), isTrue);
        expect(index.snapshot().single.label, 'Save');
        expect(index.length, 1);
      });

      test('should ignore a handle with an empty id', () {
        // Arrange
        final index = AgentElementIndex();

        // Act
        index.register(AgentElementHandle(id: ''));

        // Assert
        expect(index.length, 0);
      });

      test('should let the most recent duplicate win', () {
        // Arrange
        final index = AgentElementIndex();
        index.register(AgentElementHandle(id: 'duplicate', label: 'first'));

        // Act
        index.register(AgentElementHandle(id: 'duplicate', label: 'second'));

        // Assert
        expect(index.length, 1);
        expect(index.handle('duplicate')?.label, 'second');
      });
    });

    group('unregister', () {
      test('should remove the matching handle', () {
        // Arrange
        final index = AgentElementIndex();
        final handle = AgentElementHandle(id: 'a');
        index.register(handle);

        // Act
        final removed = index.unregister(handle);

        // Assert
        expect(removed, isTrue);
        expect(index.contains('a'), isFalse);
      });

      test('should not evict a newer handle that reused the id', () {
        // Arrange
        final index = AgentElementIndex();
        final older = AgentElementHandle(id: 'a', label: 'older');
        final newer = AgentElementHandle(id: 'a', label: 'newer');
        index.register(older);
        index.register(newer);

        // Act
        final removed = index.unregister(older);

        // Assert
        expect(removed, isFalse);
        expect(index.handle('a')?.label, 'newer');
      });
    });

    group('changes', () {
      test('should emit asynchronously when the index changes', () async {
        // Arrange
        final index = AgentElementIndex();
        var events = 0;
        final subscription = index.changes.listen((_) => events++);

        // Act
        index.register(AgentElementHandle(id: 'a'));
        final immediate = events;
        await Future<void>.delayed(Duration.zero);

        // Assert
        expect(immediate, 0);
        expect(events, 1);
        await subscription.cancel();
      });
    });

    group('reset', () {
      test('should remove every indexed element', () {
        // Arrange
        final index = AgentElementIndex();
        index.register(AgentElementHandle(id: 'a'));
        index.register(AgentElementHandle(id: 'b'));

        // Act
        index.reset();

        // Assert
        expect(index.length, 0);
      });
    });
  });

  group('AgentElementHandle', () {
    group('snapshot', () {
      test('should read live values through the supplied getters', () {
        // Arrange
        var value = 'first';
        var enabled = true;
        final handle = AgentElementHandle(
          id: 'a',
          valueGetter: () => value,
          enabledGetter: () => enabled,
        );

        // Act
        value = 'second';
        enabled = false;
        final snapshot = handle.snapshot();

        // Assert
        expect(snapshot.value, 'second');
        expect(snapshot.enabled, isFalse);
        expect(snapshot.visible, isTrue);
      });
    });

    group('normalizeValue', () {
      test('should pass JSON primitives through unchanged', () {
        // Arrange & Act & Assert
        expect(AgentElementHandle.normalizeValue(null), isNull);
        expect(AgentElementHandle.normalizeValue('a'), 'a');
        expect(AgentElementHandle.normalizeValue(2), 2);
        expect(AgentElementHandle.normalizeValue(true), isTrue);
      });

      test('should convert dates, times, and enums to strings', () {
        // Arrange
        final date = DateTime.utc(2026, 8, 20, 15, 6);

        // Act & Assert
        expect(AgentElementHandle.normalizeValue(date), date.toIso8601String());
        expect(
          AgentElementHandle.normalizeValue(
            const TimeOfDay(hour: 9, minute: 5),
          ),
          '09:05',
        );
        expect(
          AgentElementHandle.normalizeValue(AgentElementType.dropdown),
          'dropdown',
        );
      });

      test('should normalize collections recursively', () {
        // Arrange
        final value = <String, Object>{
          'items': [const TimeOfDay(hour: 1, minute: 2)],
        };

        // Act
        final normalized = AgentElementHandle.normalizeValue(value);

        // Assert
        expect(normalized, {
          'items': ['01:02'],
        });
      });
    });

    group('updateFrom', () {
      test('should copy the mutable description fields', () {
        // Arrange
        final handle = AgentElementHandle(id: 'a', label: 'old');
        final next = AgentElementHandle(
          id: 'a',
          label: 'new',
          type: AgentElementType.button,
          activator: () {},
        );

        // Act
        handle.updateFrom(next);

        // Assert
        expect(handle.label, 'new');
        expect(handle.type, AgentElementType.button);
        expect(handle.canActivate, isTrue);
        expect(handle.canSetValue, isFalse);
      });
    });
  });
}
