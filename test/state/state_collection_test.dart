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

import 'dart:async';

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

  /// When set, [get] waits on it before returning.
  ///
  /// Lets a test hold a read in flight so a reset or a superseding read can
  /// happen while the first one is still outstanding.
  Completer<void>? getGate;

  @override
  Map<String, dynamic> get parameters => _parameters;

  @override
  Query<dynamic> limit(int limit) => this;

  @override
  Future<QuerySnapshot<dynamic>> get([GetOptions? options]) async {
    final gate = getGate;
    if (gate != null) {
      await gate.future;
    }
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
    group('intentionally abandoned requests', () {
      test('should not report through onError when cleared while a fetch is in flight', () async {
        // Arrange
        final fakeQuery = _FakeQuery()..failGet = true;
        final state = _TestStateCollection(fakeQuery);
        final errors = <String?>[];
        state.onError = errors.add;
        final gate = Completer<void>();
        fakeQuery.getGate = gate;

        // Act - the view is left while the read is still in flight, so the
        // fetch is abandoned on purpose before it can resolve. It fails if it
        // were still current, which is what makes the assertion meaningful.
        final inFlight = state();
        await Future<void>.delayed(Duration.zero);
        expect(state.loading, isTrue);
        state.clear();
        gate.complete();
        await inFlight;

        // Assert
        expect(errors, isEmpty);
        expect(state.error, isNull);
        expect(state.loading, isFalse);
        expect(state.data, isNull);
      });

      test(
        'should still report a fetch failure while the view stays open',
        () async {
          // Arrange
          final fakeQuery = _FakeQuery()..failGet = true;
          final state = _TestStateCollection(fakeQuery);
          final errors = <String?>[];
          state.onError = errors.add;

          // Act
          await state();

          // Assert
          expect(errors, hasLength(1));
          expect(errors.single, contains('permission denied'));
          expect(state.error, isNotNull);
          expect(state.loading, isFalse);
        },
      );

      test('should not overwrite newer data with a superseded fetch', () async {
        // Arrange
        final fakeQuery = _FakeQuery();
        final state = _TestStateCollection(fakeQuery);
        final errors = <String?>[];
        state.onError = errors.add;
        final gate = Completer<void>();
        fakeQuery
          ..getGate = gate
          ..failGet = true
          ..snapshot = _FakeQuerySnapshot(<_FakeQueryDocumentSnapshot>[
            _FakeQueryDocumentSnapshot('doc-old', <String, dynamic>{
              'id': 'old',
            }),
          ], 1);

        // Act - the read is still in flight when the view is left, so it is
        // abandoned mid-request and would fail if it were still current.
        final abandoned = state();
        await Future<void>.delayed(Duration.zero);
        expect(state.loading, isTrue);
        state.clear();
        state.baseQuery = fakeQuery;
        gate.complete();
        await abandoned;

        // Assert - the abandoned read publishes neither data nor an error.
        expect(errors, isEmpty);
        expect(state.error, isNull);
        expect(state.data, isNull);
        expect(state.loading, isFalse);

        // Act - a fresh read takes over the state.
        fakeQuery
          ..getGate = null
          ..failGet = false
          ..snapshot = _FakeQuerySnapshot(<_FakeQueryDocumentSnapshot>[
            _FakeQueryDocumentSnapshot('new', <String, dynamic>{'id': 'stale'}),
          ], 1);
        await state();

        // Assert - only the surviving request's payload is published. The
        // published id comes from the surviving document, not the abandoned
        // one.
        expect(errors, isEmpty);
        expect(state.data, hasLength(1));
        expect((state.data as List).single, containsPair('id', 'new'));
        expect(state.error, isNull);
        expect(state.loading, isFalse);
      });

      test(
        'should not report through onError when disposed in flight',
        () async {
          // Arrange
          final fakeQuery = _FakeQuery()..failGet = true;
          final state = _TestStateCollection(fakeQuery);
          final errors = <String?>[];
          state.onError = errors.add;
          final gate = Completer<void>();
          fakeQuery.getGate = gate;

          // Act - the state is disposed while the read is still outstanding.
          final inFlight = state();
          await Future<void>.delayed(Duration.zero);
          expect(state.loading, isTrue);
          state.dispose();
          gate.complete();
          await inFlight;

          // Assert
          expect(errors, isEmpty);
        },
      );
    });

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
