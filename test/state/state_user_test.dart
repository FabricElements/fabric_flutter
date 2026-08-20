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
  });
}
