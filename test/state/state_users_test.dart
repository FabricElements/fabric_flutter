import 'package:fabric_flutter/state/state_users.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/firebase_test_harness.dart';

void main() {
  group('StateUsers', () {
    setUp(() async {
      // Arrange: mock Firebase so the Firestore instance resolves.
      await setupFirebaseForTest();
    });

    test('serialized sorts users by name', () {
      // Arrange
      final state = StateUsers();

      // Act
      state.data = [
        {'id': 'b', 'firstName': 'Zoe'},
        {'id': 'a', 'firstName': 'Ada'},
      ];

      // Assert
      final serialized = state.serialized;
      expect(serialized.map((user) => user.id).toList(), ['a', 'b']);
    });

    test('serialized reuses the cached list for the same data reference', () {
      // Arrange
      final state = StateUsers();
      state.data = [
        {'id': 'a', 'firstName': 'Ada'},
      ];

      // Act
      final first = state.serialized;
      final second = state.serialized;

      // Assert: identical instance means no re-deserialize/re-sort occurred.
      expect(identical(first, second), isTrue);
    });

    test('serialized rebuilds when data is replaced', () {
      // Arrange
      final state = StateUsers();
      state.data = [
        {'id': 'a', 'firstName': 'Ada'},
      ];
      final first = state.serialized;

      // Act
      state.data = [
        {'id': 'c', 'firstName': 'Cara'},
      ];
      final second = state.serialized;

      // Assert
      expect(identical(first, second), isFalse);
      expect(second.single.id, 'c');
    });

    test('serialized returns an empty list when data is null', () {
      // Arrange
      final state = StateUsers();

      // Act
      final serialized = state.serialized;

      // Assert
      expect(serialized, isEmpty);
    });
  });
}
