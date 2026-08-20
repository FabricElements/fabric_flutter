import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal concrete [StateShared] used to exercise the base class in
/// isolation, without any Firebase-backed subclass (document/collection/API).
class _TestState extends StateShared {
  @override
  dynamic get serialized => data;
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
    });
  });
}
