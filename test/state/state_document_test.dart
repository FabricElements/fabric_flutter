import 'package:fabric_flutter/state/state_document.dart';
import 'package:flutter_test/flutter_test.dart';

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
      test('should default to disabled with no snapshot', () {
        // Arrange & Act
        final state = _TestStateDocument();

        // Assert
        expect(state.edit, isFalse);
        expect(state.copy, isNull);
      });

      test('should capture a snapshot and notify when entering edit', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.edit = true;

        // Assert
        expect(state.edit, isTrue);
        expect(state.copy, {'id': 'doc-1', 'name': 'original'});
        expect(notified, 1);
      });

      test('should snapshot a copy that is detached from data', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;

        // Act
        state.editField('name', 'changed');

        // Assert
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});
        expect(state.copy, {'id': 'doc-1', 'name': 'original'});
      });

      test('should ignore a repeated assignment and keep the snapshot', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.edit = true;

        // Assert
        expect(notified, 0);
        expect(state.copy, {'id': 'doc-1', 'name': 'original'});
      });

      test('should keep local changes when edit mode is turned off', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');

        // Act
        state.edit = false;

        // Assert
        expect(state.edit, isFalse);
        expect(state.copy, isNull);
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});
      });

      test('should leave a null snapshot when data is empty', () {
        // Arrange
        final state = _TestStateDocument();

        // Act
        state.edit = true;

        // Assert
        expect(state.edit, isTrue);
        expect(state.copy, isNull);
      });
    });

    group('editField', () {
      test('should replace the payload so listeners are notified', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.editField('name', 'changed');

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
      test('should restore the snapshot and leave edit mode', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');

        // Act
        state.revert();

        // Assert
        expect(state.data, {'id': 'doc-1', 'name': 'original'});
        expect(state.edit, isFalse);
        expect(state.copy, isNull);
      });

      test('should notify listeners when restoring', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.editField('name', 'changed');
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.revert();

        // Assert — twice on purpose: once from the `data` setter accepting the
        // restored snapshot, once from the unconditional call that guarantees
        // the edit-mode exit is delivered. The debounce coalesces them into a
        // single rebuild outside of tests, where `kIsTest` bypasses it.
        expect(notified, 2);
      });

      test('should notify when cancelling without changing anything', () {
        // Arrange — the cancel-with-no-edits path. `copy` is a snapshot of
        // `data`, so restoring it hands the setter a fresh but structurally
        // equal payload, which the setter deliberately suppresses. Before the
        // fix `revert()` relied on that setter as its only notification, so
        // `edit` flipped to false with nothing rebuilding and the view stayed
        // stuck in edit mode.
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.revert();

        // Assert
        expect(notified, 1);
        expect(state.edit, isFalse);
        expect(state.copy, isNull);
        expect(state.data, {'id': 'doc-1', 'name': 'original'});
      });

      test('should only clear the flag when no snapshot exists', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.revert();

        // Assert
        expect(state.edit, isFalse);
        expect(state.data, {'id': 'doc-1', 'name': 'original'});
        expect(notified, 1);
      });

      test('should discard several field edits at once', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original', 'count': 1};
        state.edit = true;
        state.editField('name', 'changed');
        state.editField('count', 99);

        // Act
        state.revert();

        // Assert
        expect(state.data, {'id': 'doc-1', 'name': 'original', 'count': 1});
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
          expect(state.copy, isNull);
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
          expect(state.copy, {'id': 'doc-1', 'name': 'original'});
          expect(state.data, {'id': 'doc-1', 'name': 'changed'});
          expect(state.error, 'write denied');
        },
      );
    });

    group('clear', () {
      test('should reset edit mode and drop the snapshot', () {
        // Arrange
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;

        // Act
        state.clear();

        // Assert
        expect(state.edit, isFalse);
        expect(state.copy, isNull);
        expect(state.data, isNull);
      });
    });
  });
}
