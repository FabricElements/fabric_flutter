import 'package:fabric_flutter/state/state_users.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/debounce.dart';
import '../support/fake_state_users.dart';
import '../support/firebase_test_harness.dart';

/// [StateUsers] override that throws on first fetch attempt to test failure handling.
class FailingStateUsers extends FakeStateUsers {
  int fetchAttempts = 0;

  FailingStateUsers() : super({});

  @override
  Future<Map<String, Map<String, dynamic>>> fetchUsersById(
    List<String> uids,
  ) async {
    fetchAttempts++;
    if (fetchAttempts == 1) {
      throw 'Network error on first attempt';
    }
    return {}; // Would succeed on retry, but we never get here
  }
}

/// [StateUsers] override that succeeds for certain chunks and fails for others,
/// to test that partial batch failures don't re-read successful chunks.
class PartialFailingStateUsers extends FakeStateUsers {
  late Set<String> failingUids;

  PartialFailingStateUsers(this.failingUids) : super({});

  @override
  Future<Map<String, Map<String, dynamic>>> fetchUsersById(
    List<String> uids,
  ) async {
    // Record the request (same as FakeStateUsers)
    requests.add(List<String>.of(uids));

    // Simulate a chunk where all UIDs are in failingUids throws
    if (uids.every((uid) => failingUids.contains(uid))) {
      throw 'Network error on chunk $uids';
    }
    // Other chunks succeed with canned data
    return {
      for (final uid in uids)
        if (!failingUids.contains(uid))
          uid: {'firstName': 'User', 'os': 'ios'},
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
      final state = FakeStateUsers({});

      // Act
      final user = state.getUser('abc');

      // Assert
      expect(user.id, 'abc');
      expect(state.cachedUser('abc'), isNotNull);
      expect(state.requests, isEmpty);
    });

    test('cachedUser returns null before the identifier is requested', () {
      // Arrange
      final state = FakeStateUsers({});

      // Act & Assert
      expect(state.cachedUser('abc'), isNull);
    });

    test('resolves many identifiers with one batched read', () async {
      // Arrange
      final state = FakeStateUsers({
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
      final state = FakeStateUsers({
        'a': {'firstName': 'Ada'},
        'b': {'firstName': 'Grace'},
      });
      int notifications = 0;
      state.addListener(() => notifications++);

      // Act
      state.getUser('a');
      state.getUser('b');
      await state.flushPendingUsers();
      await settleDebounce();

      // Assert
      expect(notifications, 1);
    });

    test('does not notify when the batch resolves nothing', () async {
      // Arrange
      final state = FakeStateUsers({});
      int notifications = 0;
      state.addListener(() => notifications++);

      // Act
      state.getUser('missing');
      await state.flushPendingUsers();
      // Wait out the debounce window before asserting an absence, so the
      // expectation cannot pass merely because delivery has not happened yet.
      await settleDebounce();

      // Assert
      expect(notifications, 0);
      expect(state.cachedUser('missing')!.firstName, isNull);
    });

    test('requesting the same identifier twice reads it once', () async {
      // Arrange
      final state = FakeStateUsers({
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
      final state = FakeStateUsers({
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
      final state = FakeStateUsers({});
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
      final state = FakeStateUsers({});

      // Act
      await state.flushPendingUsers();

      // Assert
      expect(state.requests, isEmpty);
    });

    group('failed fetch handling', () {
      test(
        'caches Unknown placeholder when user is not found',
        () async {
          // Arrange
          final state = FakeStateUsers({});
          int notifications = 0;
          state.addListener(() => notifications++);

          // Act
          final placeholder = state.getUser('missing');
          await state.flushPendingUsers();
          await settleDebounce();

          // Assert
          expect(placeholder.firstName, isNull);
          expect(state.cachedUser('missing')!.firstName, isNull);
          expect(notifications, 0); // No change notification for missing user
        },
      );

      test(
        'returns cached Unknown placeholder on repeated getUser for missing user',
        () async {
          // Arrange
          final state = FakeStateUsers({});

          // Act - first call
          final first = state.getUser('missing');
          await state.flushPendingUsers();

          // Act - second call (should not re-fetch)
          final second = state.getUser('missing');
          await state.flushPendingUsers();

          // Assert
          expect(identical(first, second), isTrue);
          expect(state.requests.length, 1); // Only one request total
          expect(state.requests.single, ['missing']);
        },
      );

      test(
        'retries a failed lookup on repeated getUser calls',
        () async {
          // Arrange - FailingStateUsers throws on first fetch attempt
          final state = FailingStateUsers();

          // Act - first call triggers fetch that fails
          final first = state.getUser('abc');
          await state.flushPendingUsers();

          // Act - second call should retry the failed lookup
          state.getUser('abc');
          await state.flushPendingUsers();

          // Assert - fetch should have been attempted twice (retry after failure)
          expect(state.fetchAttempts, greaterThan(1),
              reason:
                  'Failed lookup should be retryable, not cached as permanent placeholder');
          expect(
            first.id,
            'abc',
            reason: 'First placeholder has the requested ID',
          );
          expect(
            first.firstName,
            isNull,
            reason: 'First placeholder has no real data (Unknown)',
          );
        },
      );

      test(
        'does not re-read successful chunks when one chunk fails',
        () async {
          // Arrange: Request UIDs across 3 chunks (whereInLimit=30 per chunk).
          // Chunks: [uids 1-30], [uids 31-60], [uids 61-90]
          // Fail only chunk 2 (uids 31-60).
          final failingUids = <String>{
            for (int i = 31; i <= 60; i++) 'user_$i',
          };
          final state = PartialFailingStateUsers(failingUids);

          // Act - request all 90 UIDs across the 3 chunks
          for (int i = 1; i <= 90; i++) {
            state.getUser('user_$i');
          }
          await state.flushPendingUsers();

          // Assert - chunk 1 and 3 UIDs are cached, chunk 2 UIDs are in _failedUids
          for (int i = 1; i <= 30; i++) {
            expect(state.cachedUser('user_$i')?.firstName, 'User',
                reason: 'Chunk 1 UID $i should be cached from successful fetch');
          }
          for (int i = 31; i <= 60; i++) {
            expect(state.cachedUser('user_$i')?.firstName, isNull,
                reason: 'Chunk 2 UID $i should have placeholder (fetch failed)');
          }
          for (int i = 61; i <= 90; i++) {
            expect(state.cachedUser('user_$i')?.firstName, 'User',
                reason: 'Chunk 3 UID $i should be cached from successful fetch');
          }

          // Verify initial request count (3 chunks)
          expect(state.requests.length, 3,
              reason: 'Should have made 3 chunk requests initially');

          // Act - retry all failed UIDs from chunk 2 by calling getUser for each
          for (int i = 31; i <= 60; i++) {
            state.getUser('user_$i');
          }
          await state.flushPendingUsers();

          // Assert - should only re-fetch chunk 2 (the failed UIDs), not chunks 1 and 3
          expect(state.requests.length, 4,
              reason:
                  'Should have made only 1 additional request (chunk 2), not 3 (re-reading all chunks)');
          expect(state.requests.last.length, 30,
              reason: 'Retry should request only the 30 failed UIDs from chunk 2');
          expect(state.requests.last.every((uid) => failingUids.contains(uid)),
              isTrue,
              reason: 'Retry batch should contain only UIDs that actually failed');
        },
      );
    });
  });
}
