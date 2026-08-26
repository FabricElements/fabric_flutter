import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal concrete [StateShared] used to exercise the base class in
/// isolation, without any Firebase-backed subclass (document/collection/API).
class _TestState extends StateShared {
  @override
  dynamic get serialized => data;
}

/// Concrete [StateShared] that memoizes through [StateShared.cachedSerialize].
///
/// [buildCount] records how often the conversion actually ran, so a stale memo
/// is proven rather than inferred from comparing equal results.
class _CachedTestState extends StateShared {
  /// Counts how many times the conversion body executed.
  int buildCount = 0;

  @override
  Map<String, dynamic> get serialized => cachedSerialize(data, () {
    buildCount++;
    final current = data;
    return current is Map
        ? Map<String, dynamic>.from(current)
        : <String, dynamic>{};
  });
}

void main() {
  group('StateShared', () {
    test(
      'should not throw and should still publish the update when callback throws',
      () async {
        // Arrange
        final state = _TestState();
        state.callback = (data) => throw StateError('boom callback');
        final streamed = <dynamic>[];
        state.stream.listen(streamed.add);

        // Act
        state.data = {'id': 1};
        // Stream events are delivered via a microtask even for broadcast
        // controllers, so let the event loop flush before asserting.
        await Future<void>.delayed(Duration.zero);

        // Assert: the throwing callback never escapes the setter, and the
        // debounced stream still receives the update.
        expect(streamed, [
          {'id': 1},
        ]);
      },
    );

    test(
      'should not throw and should still publish the error when onError throws',
      () async {
        // Arrange
        final state = _TestState();
        state.onError = (error) => throw StateError('boom onError');
        final streamedErrors = <String?>[];
        state.streamError.listen(streamedErrors.add);

        // Act
        state.error = 'something failed';
        await Future<void>.delayed(Duration.zero);

        // Assert
        expect(state.error, 'something failed');
        expect(streamedErrors, ['something failed']);
      },
    );

    test('should still notify listeners when callback throws', () {
      // Arrange
      final state = _TestState();
      state.callback = (data) => throw StateError('boom callback');
      var notified = false;
      state.addListener(() => notified = true);

      // Act
      state.data = {'id': 2};

      // Assert
      expect(notified, isTrue);
    });

    group('data', () {
      test(
        'should notify when the held object is mutated in place and reassigned',
        () {
          // Arrange
          final state = _TestState();
          state.data = {'count': 1};
          var notifications = 0;
          state.addListener(() => notifications++);

          // Act — mutate the object the state already holds, then hand it back.
          // `privateOldData` references that same object, so the comparison
          // baseline mutated too and a structural check cannot see the change.
          state.data['count'] = 2;
          state.data = state.data;

          // Assert
          expect(notifications, 1);
          expect(state.data, {'count': 2});
        },
      );

      test(
        'should not notify for a fresh payload that is structurally equal',
        () {
          // Arrange
          final state = _TestState();
          state.data = {'count': 1};
          var notifications = 0;
          state.addListener(() => notifications++);

          // Act — a brand new map that deep-equals the current value.
          state.data = {'count': 1};

          // Assert — a snapshot that renders identically is still deduped, so
          // the fix does not undo the structural comparison optimisation.
          expect(notifications, 0);
        },
      );

      test('should notify for a fresh payload that differs', () {
        // Arrange — positive control for the dedupe test above: proves the
        // listener does fire on this setup when the value genuinely changes.
        final state = _TestState();
        state.data = {'count': 1};
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act
        state.data = {'count': 2};

        // Assert
        expect(notifications, 1);
      });

      test('should re-enter the setter when a listener reassigns data', () {
        // Arrange — pins the caveat documented on the setter: reassigning the
        // held instance from a listener recurses, because the same-instance
        // path always notifies. The counter bounds the recursion so the test
        // terminates; without it this overflows the stack.
        final state = _TestState();
        state.data = {'count': 1};
        var depth = 0;
        state.addListener(() {
          depth++;
          if (depth >= 5) return;
          state.data = state.data;
        });

        // Act
        state.data = state.data;

        // Assert — every reassignment produced another notification, so the
        // recursion is unbounded rather than a single re-entry. If a
        // re-entrancy guard is ever added, this test must change alongside the
        // setter docstring and the CHANGELOG.
        expect(depth, 5);
      });
    });

    group('serialized cache', () {
      test('should rebuild after an in-place mutation is reassigned', () {
        // Arrange
        final state = _CachedTestState();
        state.data = {'count': 1};
        expect(state.serialized, {'count': 1});
        expect(state.buildCount, 1);

        // Act
        state.data['count'] = 2;
        state.data = state.data;

        // Assert — cachedSerialize keys on identical(), which cannot detect a
        // same-instance reassignment, so the setter drops the memo explicitly.
        expect(state.serialized, {'count': 2});
        expect(state.buildCount, 2);
      });

      test('should rebuild when a fresh payload is assigned', () {
        // Arrange
        final state = _CachedTestState();
        state.data = {'count': 1};
        state.serialized;

        // Act
        state.data = {'count': 2};

        // Assert
        expect(state.serialized, {'count': 2});
        expect(state.buildCount, 2);
      });
    });

    group('merge', () {
      test('should append entries with new ids', () {
        // Arrange
        final state = _TestState();
        final base = [
          {'id': 1, 'name': 'a'},
        ];

        // Act
        final result = state.merge(
          base: base,
          toMerge: [
            {'id': 2, 'name': 'b'},
          ],
        );

        // Assert
        expect(result, [
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ]);
      });

      test('should replace existing entries in place by id', () {
        // Arrange
        final state = _TestState();
        final base = [
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ];

        // Act
        final result = state.merge(
          base: base,
          toMerge: [
            {'id': 1, 'name': 'updated'},
          ],
        );

        // Assert — same position, replaced value, no new entry
        expect(result, [
          {'id': 1, 'name': 'updated'},
          {'id': 2, 'name': 'b'},
        ]);
      });

      test('should let a later duplicate id replace an appended entry', () {
        // Arrange — mirrors the old indexWhere behavior where a second incoming
        // item with the same new id overwrites the first that was appended.
        final state = _TestState();

        // Act
        final result = state.merge(
          base: [],
          toMerge: [
            {'id': 5, 'name': 'first'},
            {'id': 5, 'name': 'second'},
          ],
        );

        // Assert
        expect(result, [
          {'id': 5, 'name': 'second'},
        ]);
      });

      test('should not mutate base', () {
        // Arrange
        final state = _TestState();
        final base = [
          {'id': 1, 'name': 'a'},
        ];

        // Act
        final result = state.merge(
          base: base,
          toMerge: [
            {'id': 1, 'name': 'updated'},
            {'id': 2, 'name': 'b'},
          ],
        );

        // Assert — the caller's list is untouched and the result is a new list.
        expect(base, [
          {'id': 1, 'name': 'a'},
        ]);
        expect(identical(result, base), isFalse);
      });

      test('should notify when the result is assigned back to data', () {
        // Arrange
        final state = _TestState();
        final seed = [
          {'id': 1, 'name': 'a'},
        ];
        state.data = seed;
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act — the canonical pagination/stream-merge call shape.
        state.data = state.merge(
          base: state.data,
          toMerge: [
            {'id': 2, 'name': 'b'},
          ],
        );

        // Assert
        expect(notifications, 1);
        expect(state.data, [
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ]);
        // The seed list doubles as the comparison baseline, so mutating it
        // would have made the merged result undetectable.
        expect(seed, [
          {'id': 1, 'name': 'a'},
        ]);
      });
    });
  });
}
