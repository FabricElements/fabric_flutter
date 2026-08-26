import 'package:fabric_flutter/state/state_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/firebase_test_harness.dart';

void main() {
  group('StateUser', () {
    setUp(() async {
      // Arrange: mock Firebase so StateUser singletons resolve.
      await setupFirebaseForTest();
    });

    test('serialized reflects the id stored in data', () {
      // Arrange
      final state = StateUser();

      // Act
      state.data = {'id': 'user-123', 'firstName': 'Ada'};

      // Assert
      expect(state.serialized.id, 'user-123');
      expect(state.serialized.firstName, 'Ada');
    });

    test('serialized returns an empty user when data is null', () {
      // Arrange
      final state = StateUser();

      // Act
      final user = state.serialized;

      // Assert
      expect(user.id, isNull);
      expect(user.firstName, isNull);
    });

    test('serialized reuses the cached instance for the same data', () {
      // Arrange
      final state = StateUser();
      state.data = {'id': 'user-123', 'firstName': 'Ada'};

      // Act
      final first = state.serialized;
      final second = state.serialized;

      // Assert: identical instance means no rebuild via fromJson occurred.
      expect(identical(first, second), isTrue);
    });

    test('serialized rebuilds when data is replaced', () {
      // Arrange
      final state = StateUser();
      state.data = {'id': 'user-123', 'firstName': 'Ada'};
      final first = state.serialized;

      // Act
      state.data = {'id': 'user-456', 'firstName': 'Grace'};
      final second = state.serialized;

      // Assert
      expect(identical(first, second), isFalse);
      expect(second.id, 'user-456');
    });

    group('serialized deserialization error handling', () {
      test('sets error when fromJson throws on invalid enum value', () {
        // Arrange
        final state = StateUser();
        // os field has no unknownEnumValue, so invalid value will throw
        state.data = {'id': 'user-123', 'os': 'invalid-os-value'};

        // Act
        final _ = state.serialized;

        // Assert
        expect(state.error, isNotNull);
        expect(state.error, contains('Invalid'));
      });

      test('returns a fallback user when deserialization fails', () {
        // Arrange
        final state = StateUser();
        state.data = {'id': 'user-123', 'os': 'invalid-os-value'};

        // Act
        final user = state.serialized;

        // Assert: fallback has default values but still looks valid
        expect(user.role, 'unknown');
        expect(user.id, isNull);
        expect(user.firstName, isNull);
      });

      test(
        'sets hadSerializationError flag on deserialization failure',
        () {
          // Arrange
          final state = StateUser();
          state.data = {'id': 'user-123', 'os': 'invalid-os-value'};

          // Act
          final _ = state.serialized;

          // Assert
          expect(state.hadSerializationError, isTrue);
        },
      );

      test(
        'reports deserialization error on repeated reads of same failure',
        () {
          // Arrange
          final state = StateUser();
          state.data = {'id': 'user-123', 'os': 'invalid-os-value'};
          List<bool> errorFlags = [];

          // Act
          final _ = state.serialized; // First read
          errorFlags.add(state.hadSerializationError);

          state.serialized; // Second read of same data
          errorFlags.add(state.hadSerializationError);

          // Assert - hadSerializationError flag is set on every read
          expect(errorFlags.length, 2);
          expect(errorFlags.every((flag) => flag), isTrue,
              reason:
                  'hadSerializationError flag should be true on every read of '
                  'deserialization failure, not dedup\'d away');
        },
      );
    });
  });
}
