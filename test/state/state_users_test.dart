import 'package:fabric_flutter/state/state_users.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/firebase_test_harness.dart';

/// Records the batched lookups issued by [StateUsers] and returns canned docs.
///
/// Overriding the fetch keeps the batching assertions free of Firestore while
/// still exercising the real queue, chunking, and notification logic.
class _RecordingStateUsers extends StateUsers {
  _RecordingStateUsers(this.documents);

  /// Holds the payload returned for each requested identifier.
  final Map<String, Map<String, dynamic>> documents;

  /// Captures every chunk handed to the fetch so tests can assert batching.
  final List<List<String>> requests = [];

  @override
  Future<Map<String, Map<String, dynamic>>> fetchUsersById(
    List<String> uids,
  ) async {
    requests.add(List<String>.of(uids));
    return {
      for (final uid in uids)
        if (documents.containsKey(uid)) uid: documents[uid]!,
    };
  }
}

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

  group('StateUsers batched lookups', () {
    setUp(() async {
      // Arrange: mock Firebase so the Firestore instance resolves.
      await setupFirebaseForTest();
    });

    test('chunkUids splits identifiers at the whereIn limit', () {
      // Arrange
      final uids = List<String>.generate(65, (index) => 'u$index');

      // Act
      final chunks = StateUsers.chunkUids(uids);

      // Assert
      expect(chunks.length, 3);
      expect(chunks[0].length, StateUsers.whereInLimit);
      expect(chunks[1].length, StateUsers.whereInLimit);
      expect(chunks[2].length, 5);
      expect(chunks.expand((chunk) => chunk).toList(), uids);
    });

    test('chunkUids returns no chunks for an empty list', () {
      // Arrange, Act
      final chunks = StateUsers.chunkUids([]);

      // Assert
      expect(chunks, isEmpty);
    });

    test('getUser returns a placeholder without blocking', () {
      // Arrange
      final state = _RecordingStateUsers({});

      // Act
      final user = state.getUser('abc');

      // Assert
      expect(user.id, 'abc');
      expect(state.cachedUser('abc'), isNotNull);
      expect(state.requests, isEmpty);
    });

    test('cachedUser returns null before the identifier is requested', () {
      // Arrange
      final state = _RecordingStateUsers({});

      // Act & Assert
      expect(state.cachedUser('abc'), isNull);
    });

    test('resolves many identifiers with one batched read', () async {
      // Arrange
      final state = _RecordingStateUsers({
        'a': {'firstName': 'Ada'},
        'b': {'firstName': 'Grace'},
        'c': {'firstName': 'Alan'},
      });

      // Act
      state.getUser('a');
      state.getUser('b');
      state.getUser('c');
      await state.flushPendingUsers();

      // Assert
      expect(state.requests.length, 1);
      expect(state.requests.single..sort(), ['a', 'b', 'c']);
      expect(state.cachedUser('a')!.firstName, 'Ada');
      expect(state.cachedUser('c')!.firstName, 'Alan');
    });

    test('notifies listeners once for the whole batch', () async {
      // Arrange
      final state = _RecordingStateUsers({
        'a': {'firstName': 'Ada'},
        'b': {'firstName': 'Grace'},
      });
      int notifications = 0;
      state.addListener(() => notifications++);

      // Act
      state.getUser('a');
      state.getUser('b');
      await state.flushPendingUsers();

      // Assert
      expect(notifications, 1);
    });

    test('does not notify when the batch resolves nothing', () async {
      // Arrange
      final state = _RecordingStateUsers({});
      int notifications = 0;
      state.addListener(() => notifications++);

      // Act
      state.getUser('missing');
      await state.flushPendingUsers();

      // Assert
      expect(notifications, 0);
      expect(state.cachedUser('missing')!.firstName, isNull);
    });

    test('requesting the same identifier twice reads it once', () async {
      // Arrange
      final state = _RecordingStateUsers({
        'a': {'firstName': 'Ada'},
      });

      // Act
      state.getUser('a');
      state.getUser('a');
      state.prefetchUsers(['a', 'a']);
      await state.flushPendingUsers();

      // Assert
      expect(state.requests.single, ['a']);
    });

    test('does not re-read an identifier already resolved', () async {
      // Arrange
      final state = _RecordingStateUsers({
        'a': {'firstName': 'Ada'},
      });
      state.getUser('a');
      await state.flushPendingUsers();

      // Act
      state.getUser('a');
      await state.flushPendingUsers();

      // Assert
      expect(state.requests.length, 1);
    });

    test('prefetchUsers chunks large requests', () async {
      // Arrange
      final state = _RecordingStateUsers({});
      final uids = List<String>.generate(45, (index) => 'u$index');

      // Act
      state.prefetchUsers(uids);
      await state.flushPendingUsers();

      // Assert
      expect(state.requests.length, 2);
      expect(state.requests.first.length, StateUsers.whereInLimit);
      expect(state.requests.last.length, 15);
    });

    test('flushPendingUsers is a no-op when nothing is queued', () async {
      // Arrange
      final state = _RecordingStateUsers({});

      // Act
      await state.flushPendingUsers();

      // Assert
      expect(state.requests, isEmpty);
    });
  });
}
