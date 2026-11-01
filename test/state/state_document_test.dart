// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'package:cloud_firestore/cloud_firestore.dart';
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

    group('error paths keep last good data', () {
      test(
        'call() should keep data and surface error when get() throws',
        () async {
          // Arrange
          final fakeRef = _FakeDocumentReference();
          fakeRef.snapshot = _FakeDocumentSnapshot(<String, dynamic>{
            'id': 'doc-1',
          });
          final state = _TestStateDocument();
          state.ref = fakeRef;
          await state();
          expect(state.data, isNotNull);

          // Act - fetch fails after data already loaded.
          fakeRef.failGet = true;
          state.initialized = false;
          await state();

          // Assert - last good data kept, error surfaced.
          expect(state.data, isNotNull);
          expect(state.error, isNotNull);
        },
      );

      test(
        'call() should keep data when snapshot reports exists = false',
        () async {
          // Arrange
          final fakeRef = _FakeDocumentReference();
          fakeRef.snapshot = _FakeDocumentSnapshot(<String, dynamic>{
            'id': 'doc-1',
          });
          final state = _TestStateDocument();
          state.ref = fakeRef;
          await state();
          expect(state.data, isNotNull);

          // Act - document reported missing.
          fakeRef.snapshot = _FakeDocumentSnapshot(null, exists: false);
          state.initialized = false;
          await state();

          // Assert - data from last good read survives.
          expect(state.data, isNotNull);
        },
      );

      test('listen() should keep data when stream reports an error', () async {
        // Arrange
        final fakeRef = _FakeDocumentReference();
        fakeRef.snapshot = _FakeDocumentSnapshot(<String, dynamic>{
          'id': 'doc-1',
        });
        final state = _TestStateDocument();
        state.ref = fakeRef;
        state.listen();
        await settleDebounce();
        expect(state.data, isNotNull);

        // Act - stream error after data already loaded.
        fakeRef.failStream = true;
        state.initialized = false;
        state.listen();
        await settleDebounce();

        // Assert - last good data kept, error surfaced.
        expect(state.data, isNotNull);
        expect(state.error, isNotNull);
      });
    });
  });
}

/// Minimal fake [DocumentSnapshot] for tests.
///
/// Firestore marks [DocumentReference] `@sealed`; these fakes implement it
/// for testing only and never escape this file.
class _FakeDocumentSnapshot implements DocumentSnapshot<dynamic> {
  /// Creates a fake snapshot carrying [value], reporting [exists].
  _FakeDocumentSnapshot(this._value, {bool exists = true})
    : _exists = exists; // ignore: prefer_initializing_formals

  final dynamic _value;

  /// Whether the snapshot reports the document as existing.
  final bool _exists;

  @override
  String get id => 'doc-1';

  @override
  bool get exists => _exists; // ignore: prefer_initializing_formals

  @override
  dynamic data({bool includeMetadataChanges = false}) => _value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal fake [DocumentReference] for tests.
class _FakeDocumentReference implements DocumentReference<dynamic> {
  /// The snapshot returned by [get] and by [snapshots] stream events.
  _FakeDocumentSnapshot snapshot = _FakeDocumentSnapshot(<String, dynamic>{
    'id': 'doc-1',
  });

  /// Whether [get] should throw instead of returning [snapshot].
  bool failGet = false;

  /// Whether [snapshots] should surface an error after the first event.
  bool failStream = false;

  @override
  String get path => 'example/doc-1';

  @override
  String get id => 'doc-1';

  @override
  Future<DocumentSnapshot<dynamic>> get([GetOptions? options]) async {
    if (failGet) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'permission denied',
      );
    }
    return snapshot;
  }

  @override
  Stream<DocumentSnapshot<dynamic>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield snapshot;
    if (failStream) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'permission denied',
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
