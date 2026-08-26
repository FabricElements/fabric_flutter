import 'package:fabric_flutter/state/state_document.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/debounce.dart';

/// Concrete [StateDocument] that captures writes instead of reaching Firestore.
///
/// Overriding [set] keeps the edit lifecycle testable without a live backend or
/// a document reference.
class _TestStateDocument extends StateDocument {
  /// Records every payload passed to [set].
  final List<Map<String, dynamic>> writes = [];

  /// Records the `merge` flag of every [set] call.
  final List<bool> merges = [];

  /// When set, [set] throws this value to simulate a failed write.
  Object? failWith;

  @override
  Future<void> set(Map<String, dynamic> newData, {bool merge = false}) async {
    if (failWith != null) throw failWith!;
    writes.add(newData);
    merges.add(merge);
  }

  @override
  dynamic get serialized => data;
}

void main() {
  group('StateDocument edit lifecycle', () {
    group('edit', () {
      test('should default to disabled', () {
        // Arrange & Act
        final state = _TestStateDocument();

        // Assert
        expect(state.edit, isFalse);
      });

      test('should notify when entering edit mode', () async {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        await settleDebounce();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.edit = true;
        await settleDebounce();

        // Assert
        expect(state.edit, isTrue);
        expect(notified, 1);
      });

      test('should ignore a repeated assignment and not notify', () async {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');
        var notified = 0;
        state.addListener(() => notified++);

        // Act — re-applying the same flag is a no-op.
        state.edit = true;

        // Assert
        expect(notified, 0);
      });

      test('should keep local changes when edit mode is turned off', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');

        // Act
        state.edit = false;

        // Assert — turning off edit simply discards the draft; data is unchanged.
        expect(state.edit, isFalse);
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});
      });
    });

    group('editField', () {
      test('should replace the payload so listeners are notified', () async {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        await settleDebounce();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.editField('name', 'changed');
        await settleDebounce();

        // Assert
        expect(notified, 1);
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});
      });

      test('should add a key that did not exist yet', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1'};

        // Act
        state.editField('extra', 42);

        // Assert
        expect(state.data, {'id': 'doc-1', 'extra': 42});
      });

      test('should start a fresh payload when data is null', () {
        // Arrange
        final state = _TestStateDocument();

        // Act
        state.editField('name', 'first');

        // Assert
        expect(state.data, {'name': 'first'});
      });

      test('should not notify when the assigned value is unchanged', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.editField('name', 'original');

        // Assert
        expect(notified, 0);
      });
    });

    group('revert', () {
      test('should discard the copy draft and leave edit mode', () {
        // Arrange — under the new model, edits are written to [copy] rather
        // than [data], so [data] is unchanged during an edit session. Reverting
        // discards the in-progress draft; there is nothing to restore in [data].
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        // Simulate an in-progress draft mutation.
        state.copy = {'id': 'doc-1', 'name': 'in-progress'};

        // Act
        state.revert();

        // Assert — draft is discarded; data is unchanged; edit mode is off.
        expect(state.edit, isFalse);
        expect(state.data, {'id': 'doc-1', 'name': 'original'});
        expect(state.copy, {'id': 'doc-1', 'name': 'original'});
      });

      test('should notify listeners', () async {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        await settleDebounce();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.revert();
        await settleDebounce();

        // Assert — exactly one notification from the unconditional
        // notifyListeners() call; no data-setter notification fires because
        // data does not change.
        expect(notified, 1);
      });

      test('should notify even when no draft was ever touched', () async {
        // Arrange — cancel without making any draft mutation.
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        await settleDebounce();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.revert();
        await settleDebounce();

        // Assert — listeners still observe the edit-mode exit.
        expect(notified, 1);
        expect(state.edit, isFalse);
        expect(state.data, {'id': 'doc-1', 'name': 'original'});
      });

      test('should notify even when edit mode was never entered', () async {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        await settleDebounce();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.revert();
        await settleDebounce();

        // Assert
        expect(state.edit, isFalse);
        expect(state.data, {'id': 'doc-1', 'name': 'original'});
        expect(notified, 1);
      });

      test('editField changes should NOT be rolled back by revert()', () {
        // This pins the breaking-change contract: editField writes directly
        // to [data], so revert() cannot undo it. Any consumer that used
        // editField + revert() expecting a rollback must migrate to the
        // copy-based workflow.
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});

        // Act
        state.revert();

        // Assert — data retains the editField change; only edit mode is cleared.
        expect(state.edit, isFalse);
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});
      });
    });

    group('save', () {
      test(
        'should write the payload without the id and leave edit mode',
        () async {
          // Arrange
          final state = _TestStateDocument();
          state.data = {'id': 'doc-1', 'name': 'original'};
          state.edit = true;
          state.editField('name', 'changed');

          // Act
          await state.save();

          // Assert
          expect(state.writes.single, {'name': 'changed'});
          expect(state.merges.single, isTrue);
          expect(state.edit, isFalse);
        },
      );

      test('should keep the committed data in place', () async {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');

        // Act
        await state.save();

        // Assert
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});
      });

      test('should forward a merge override', () async {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'value'};

        // Act
        await state.save(merge: false);

        // Assert
        expect(state.merges.single, isFalse);
      });

      test('should do nothing when there is no payload', () async {
        // Arrange
        final state = _TestStateDocument();
        state.edit = true;

        // Act
        await state.save();

        // Assert
        expect(state.writes, isEmpty);
        expect(state.edit, isTrue);
      });

      test(
        'should stay in edit mode and record the error when saving fails',
        () async {
          // Arrange
          final state = _TestStateDocument();
          state.data = {'id': 'doc-1', 'name': 'original'};
          state.edit = true;
          state.editField('name', 'changed');
          state.failWith = 'write denied';

          // Act
          await expectLater(state.save(), throwsA('write denied'));

          // Assert: the user's changes survive a failed write.
          expect(state.edit, isTrue);
          expect(state.data, {'id': 'doc-1', 'name': 'changed'});
          expect(state.error, 'write denied');
        },
      );
    });

    group('clear', () {
      test('should reset edit mode and data', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;

        // Act
        state.clear();

        // Assert
        expect(state.edit, isFalse);
        expect(state.data, isNull);
      });

      test('should invalidate the typed draft', () {
        // Arrange — prime the draft then replace it with a stale value.
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.copy = {'stale': true}; // manually inject a stale draft
        expect(state.copy, {'stale': true}); // confirm it's there

        // Act
        state.clear();

        // Assert — after clear, data is null so the draft is also null.
        expect(state.copy, isNull);
      });
    });

    group('copy draft invalidation', () {
      test('revert() should discard an in-progress draft and rebuild from data', () {
        // Arrange — inject a stale copy to verify invalidation fires.
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.copy = {'stale': true}; // manually set to something wrong
        expect(state.copy, {'stale': true});

        // Act
        state.revert();

        // Assert — draft is invalidated; next read rebuilds from unchanged data.
        expect(state.copy, {'id': 'doc-1', 'name': 'original'});
        expect(state.edit, isFalse);
      });

      test('save() should invalidate the typed draft', () async {
        // Arrange — enter edit and inject a stale copy.
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');
        state.copy = {'stale': true}; // manually set to something wrong

        // Act
        await state.save();

        // Assert — exitEdit() was called: draft is invalidated and the next
        // read rebuilds from the current data (the stub leaves data in place).
        expect(state.copy, state.data);
        expect(state.edit, isFalse);
      });
    });
  });
}
