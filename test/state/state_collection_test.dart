// ignore_for_file: subtype_of_sealed_class, must_be_immutable

/// Regression tests for [StateCollection] error-path data retention.
///
/// These tests use hand-rolled [Query] fakes (there is no
/// `fake_cloud_firestore` dependency in this package) to prove that live
/// listener errors and one-shot fetch errors keep the last good data instead
/// of wiping the state. Firestore marks [Query] and [QueryDocumentSnapshot]
/// `@sealed`; these fakes implement them for testing only and never escape
/// this file.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/state/state_collection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/debounce.dart';

/// Minimal fake [DocumentSnapshot] used by the fake query results.
class _FakeQueryDocumentSnapshot implements QueryDocumentSnapshot<dynamic> {
  /// Creates a fake document snapshot for [id] carrying [value].
  _FakeQueryDocumentSnapshot(this.id, this.value);

  @override
  final String id;

  /// The payload reported by [data].
  final dynamic value;

  @override
  dynamic data({bool includeMetadataChanges = false}) => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal fake [QuerySnapshot] carrying canned [docs] and [size].
class _FakeQuerySnapshot implements QuerySnapshot<dynamic> {
  /// Creates a fake snapshot exposing [docs] and [size].
  _FakeQuerySnapshot(this.docs, this.size);

  @override
  final List<QueryDocumentSnapshot<dynamic>> docs;

  @override
  final int size;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake [Query] that never reaches Firestore.
///
/// The `limit` chain must return a query with the recorded parameters because
/// [StateCollection.query] applies `.limit(limit * page)` to the base query
/// before every read, and `isSameQuery` compares the resulting parameters.
class _FakeQuery implements Query<dynamic> {
  /// Creates a fake query, optionally already carrying recorded parameters.
  _FakeQuery({Map<String, dynamic>? parameters})
    : _parameters = parameters ?? <String, dynamic>{};

  final Map<String, dynamic> _parameters;

  /// Whether [get] should throw instead of returning [snapshot].
  bool failGet = false;

  /// The snapshot returned by [get] and by the [snapshots] stream events.
  _FakeQuerySnapshot snapshot = _FakeQuerySnapshot(
    <_FakeQueryDocumentSnapshot>[],
    0,
  );

  /// Whether [snapshots] should surface an error after the first event.
  bool failStream = false;

  @override
  Map<String, dynamic> get parameters => _parameters;

  @override
  Query<dynamic> limit(int limit) => this;

  @override
  Future<QuerySnapshot<dynamic>> get([GetOptions? options]) async {
    if (failGet) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'permission denied',
      );
    }
    return snapshot;
  }

  @override
  Stream<QuerySnapshot<dynamic>> snapshots({
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

/// Concrete [StateCollection] over a [_FakeQuery] for tests.
class _TestStateCollection extends StateCollection {
  /// Creates a collection state wired to [query].
  _TestStateCollection(this.fakeQuery) {
    baseQuery = fakeQuery;
  }

  /// The fake query backing this state.
  final _FakeQuery fakeQuery;

  @override
  dynamic get serialized => data;
}

void main() {
  group('StateCollection', () {
    test(
      'should keep last good data when snapshots stream reports an error',
      () async {
        // Arrange
        final fakeQuery = _FakeQuery();
        fakeQuery.snapshot = _FakeQuerySnapshot(<_FakeQueryDocumentSnapshot>[
          _FakeQueryDocumentSnapshot('doc-1', <String, dynamic>{'id': '1'}),
        ], 1);
        final state = _TestStateCollection(fakeQuery);
        state.listen();
        await settleDebounce();
        expect(state.data, isNotEmpty);

        // Act - stream error after data already loaded.
        fakeQuery.failStream = true;
        state.initialized = false;
        state.listen();
        await settleDebounce();

        // Assert - last good data kept, error surfaced.
        expect(state.data, isNotEmpty);
        expect(state.error, isNotNull);
      },
    );

    test(
      'should keep last good data when get() throws after data loaded',
      () async {
        // Arrange
        final fakeQuery = _FakeQuery();
        fakeQuery.snapshot = _FakeQuerySnapshot(<_FakeQueryDocumentSnapshot>[
          _FakeQueryDocumentSnapshot('doc-1', <String, dynamic>{'id': '1'}),
        ], 1);
        final state = _TestStateCollection(fakeQuery);
        await state();
        expect(state.data, isNotEmpty);

        // Act
        fakeQuery.failGet = true;
        state.initialized = false;
        await state();

        // Assert
        expect(state.data, isNotEmpty);
        expect(state.error, isNotNull);
      },
    );
  });
}
