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
        state.data = {'id': 'doc-1', 'name': 'changed'};
        state.edit = true;
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
        state.data = {'id': 'doc-1', 'name': 'changed'};
        state.edit = true;

        // Act
        state.edit = false;

        // Assert — turning off edit simply discards the draft; data is unchanged.
        expect(state.edit, isFalse);
        expect(state.data, {'id': 'doc-1', 'name': 'changed'});
      });
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
      test('setting edit = false should discard a stale draft and rebuild from data', () {
        // Arrange — inject a stale copy to verify draft invalidation fires on
        // edit-mode exit. Uses edit = false directly; same invalidation path
        // as the removed lifecycle methods.
        final state = _TestStateDocument();
        state.data = {'id': 'doc-1', 'name': 'original'};
        state.edit = true;
        state.copy = {'stale': true}; // manually set to something wrong
        expect(state.copy, {'stale': true});

        // Act
        state.edit = false;

        // Assert — draft is invalidated; next read rebuilds from unchanged data.
        expect(state.copy, {'id': 'doc-1', 'name': 'original'});
        expect(state.edit, isFalse);
      });
    });
  });
}
