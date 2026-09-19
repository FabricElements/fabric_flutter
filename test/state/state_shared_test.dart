import 'dart:convert';

import 'package:fabric_flutter/helper/filter_helper.dart';
import 'package:fabric_flutter/serialized/filter_data.dart';
import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/debounce.dart';

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

/// Concrete [StateShared] that opts out of debouncing.
///
/// `debounceTime` is a public overridable getter, so returning `0` is the
/// documented way for a consumer to disable coalescing. This subclass exists to
/// pin that the opt-out still publishes on every channel.
class _ImmediateState extends StateShared {
  @override
  int get debounceTime => 0;

  @override
  dynamic get serialized => data;
}

/// Concrete [StateShared] whose debouncing can be switched off mid-flight.
///
/// Used to prove the opt-out cancels a timer that is already pending, so a
/// stale deferred delivery cannot arrive after an immediate one.
class _ToggleDebounceState extends StateShared {
  /// When `true`, [debounceTime] reports `0` and publishing is immediate.
  bool immediate = false;

  @override
  int get debounceTime => immediate ? 0 : super.debounceTime;

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
        // The publish is debounced, so wait for the trailing-edge timer.
        await settleDebounce();

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

    test('should still notify listeners when callback throws', () async {
      // Arrange
      final state = _TestState();
      state.callback = (data) => throw StateError('boom callback');
      var notified = false;
      state.addListener(() => notified = true);

      // Act
      state.data = {'id': 2};
      await settleDebounce();

      // Assert
      expect(notified, isTrue);
    });

    group('data', () {
      test(
        'should notify when the held object is mutated in place and reassigned',
        () async {
          // Arrange
          final state = _TestState();
          state.data = {'count': 1};
          // Let the seed's own debounced publish land before listening, so the
          // assertions below count only notifications the Act step caused.
          await settleDebounce();
          var notifications = 0;
          state.addListener(() => notifications++);

          // Act — mutate the object the state already holds, then hand it back.
          // `privateOldData` references that same object, so the comparison
          // baseline mutated too and a structural check cannot see the change.
          state.data['count'] = 2;
          state.data = state.data;
          await settleDebounce();

          // Assert
          expect(notifications, 1);
          expect(state.data, {'count': 2});
        },
      );

      test(
        'should not notify for a fresh payload that is structurally equal',
        () async {
          // Arrange
          final state = _TestState();
          state.data = {'count': 1};
          await settleDebounce();
          var notifications = 0;
          state.addListener(() => notifications++);

          // Act — a brand new map that deep-equals the current value.
          state.data = {'count': 1};
          // Wait out the debounce before asserting an absence: without this the
          // expectation passes vacuously, because nothing has been delivered
          // yet regardless of whether the guard works.
          await settleDebounce();

          // Assert — a snapshot that renders identically is still deduped, so
          // the fix does not undo the structural comparison optimisation.
          expect(notifications, 0);
        },
      );

      test('should notify for a fresh payload that differs', () async {
        // Arrange — positive control for the dedupe test above: proves the
        // listener does fire on this setup when the value genuinely changes.
        final state = _TestState();
        state.data = {'count': 1};
        await settleDebounce();
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act
        state.data = {'count': 2};
        await settleDebounce();

        // Assert
        expect(notifications, 1);
      });

      test(
        'should re-enter the setter when a listener reassigns data',
        () async {
          // Arrange — pins the caveat documented on the setter: reassigning the
          // held instance from a listener notifies again, because the
          // same-instance path always publishes. Each re-entry schedules a
          // fresh debounce timer rather than recursing on the stack, so the
          // chain unwinds across successive windows. The counter bounds it so
          // the test terminates.
          final state = _TestState();
          state.initialized = true;
          state.data = {'count': 1};
          await settleDebounceInitialized();
          var depth = 0;
          state.addListener(() {
            depth++;
            if (depth >= 5) return;
            state.data = state.data;
          });

          // Act
          state.data = state.data;
          for (var i = 0; i < 6; i++) {
            await settleDebounceInitialized();
          }

          // Assert — every reassignment produced another notification, so the
          // re-entry is unbounded rather than a single pass. If a re-entrancy
          // guard is ever added, this test must change alongside the setter
          // docstring and the CHANGELOG.
          expect(depth, 5);
        },
      );
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

      test('should notify when the result is assigned back to data', () async {
        // Arrange
        final state = _TestState();
        final seed = [
          {'id': 1, 'name': 'a'},
        ];
        state.data = seed;
        await settleDebounce();
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act — the canonical pagination/stream-merge call shape.
        state.data = state.merge(
          base: state.data,
          toMerge: [
            {'id': 2, 'name': 'b'},
          ],
        );
        await settleDebounce();

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

    group('debounce', () {
      test('should coalesce a burst into a single delivery', () async {
        // Arrange
        final state = _TestState();
        state.initialized = true;
        await settleDebounceInitialized();
        var notifications = 0;
        state.addListener(() => notifications++);
        final streamed = <dynamic>[];
        final subscription = state.stream.listen(streamed.add);

        // Act — five distinct payloads inside one debounce window.
        for (var i = 0; i < 5; i++) {
          state.data = {'count': i};
        }
        await settleDebounceInitialized();

        // Assert — the burst collapses to one rebuild carrying the last value,
        // which is the optimisation the debounce exists to provide.
        expect(notifications, 1);
        expect(streamed, [
          {'count': 4},
        ]);
        await subscription.cancel();
      });

      test('should deliver each burst that is separated by silence', () async {
        // Arrange — positive control for the coalescing test above: proves the
        // single delivery is coalescing rather than starvation.
        final state = _TestState();
        state.initialized = true;
        await settleDebounceInitialized();
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act
        state.data = {'count': 1};
        await settleDebounceInitialized();
        state.data = {'count': 2};
        await settleDebounceInitialized();

        // Assert
        expect(notifications, 2);
      });
    });

    group('debounceTime opt-out', () {
      test('should publish on every channel when debouncing is off', () async {
        // Arrange — `debounceTime => 0` is the supported way to opt out, so it
        // must deliver the same three things the debounced path delivers:
        // a stream event, a listener notification, and a callback invocation.
        final state = _ImmediateState();
        final streamed = <dynamic>[];
        final subscription = state.stream.listen(streamed.add);
        final callbacks = <dynamic>[];
        state.callback = callbacks.add;
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act
        state.data = {'count': 1};
        // Stream events are delivered via a microtask, so let the event loop
        // flush. No timer is involved on this path.
        await Future<void>.delayed(Duration.zero);

        // Assert
        expect(notifications, 1);
        expect(streamed, [
          {'count': 1},
        ]);
        expect(callbacks, [
          {'count': 1},
        ]);
        await subscription.cancel();
      });

      test('should publish synchronously rather than on a timer', () async {
        // Arrange — positive control: pins that the opt-out really bypasses the
        // debounce, so the assertions above cannot pass via a deferred timer.
        final state = _ImmediateState();
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act
        state.data = {'count': 1};

        // Assert — no await, so a timer-based delivery would still read 0.
        expect(notifications, 1);
      });

      test(
        'should drop a pending timer when debouncing is turned off',
        () async {
          // Arrange — a state that debounces first, then opts out mid-flight.
          final state = _ToggleDebounceState();
          state.data = {'count': 1};
          var notifications = 0;
          state.addListener(() => notifications++);

          // Act — the immediate publish must also cancel the timer the first
          // assignment scheduled, or a stale delivery arrives afterwards.
          state.immediate = true;
          state.data = {'count': 2};
          await settleDebounce();

          // Assert
          expect(notifications, 1);
        },
      );
    });

    group('selected', () {
      test('should notify when a read-mutate-write changes the list', () async {
        // Arrange — `selected` hands back `selectedItems` itself, so a caller
        // that reads it, mutates it, and assigns it back compares the list
        // against itself. Without the same-instance escape hatch the structural
        // guard reports "unchanged" and swallows a real selection change.
        final state = _TestState();
        state.selected = ['a'];
        await settleDebounce();
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act
        final current = state.selected;
        current.add('b');
        state.selected = current;
        await settleDebounce();

        // Assert
        expect(notifications, 1);
        expect(state.selected, ['a', 'b']);
      });

      test('should still skip an equivalent replacement list', () async {
        // Arrange — negative control: the structural guard must survive the
        // escape hatch, so a fresh but equal list is still deduped.
        final state = _TestState();
        state.selected = ['a'];
        await settleDebounce();
        var notifications = 0;
        state.addListener(() => notifications++);

        // Act
        state.selected = ['a'];
        await settleDebounce();

        // Assert
        expect(notifications, 0);
      });

      test(
        'should notify when a genuinely different list is assigned',
        () async {
          // Arrange — positive control for the dedupe test above.
          final state = _TestState();
          state.selected = ['a'];
          await settleDebounce();
          var notifications = 0;
          state.addListener(() => notifications++);

          // Act
          state.selected = ['a', 'b'];
          await settleDebounce();

          // Assert
          expect(notifications, 1);
        },
      );
    });

    group('filtersEncoded', () {
      test('should return null when no filter is active', () {
        // Arrange
        final state = _TestState();

        // Act & Assert
        expect(state.filtersEncoded, isNull);
      });

      test('should encode an active filter into a decodable payload', () {
        // Arrange — positive control for the null case above: proves the
        // getter can produce a payload at all, so `isNull` is a real branch.
        final state = _TestState();
        state.filters = [
          FilterData(
            id: 'status',
            operator: FilterOperator.equal,
            value: 'active',
          ),
        ];

        // Act
        final encoded = state.filtersEncoded;

        // Assert
        expect(encoded, isNotNull);
        final restored = FilterHelper.decode(encoded);
        expect(restored, hasLength(1));
        expect(restored.first.id, 'status');
        expect(restored.first.operator, FilterOperator.equal);
      });

      test('should never emit a table name or SQL text', () {
        // Arrange — `filterGroup` is the table name used by the SQL path, so
        // it is the exact token that must not appear in this payload.
        final state = _TestState();
        state.filters = [
          FilterData(
            id: 'status',
            operator: FilterOperator.equal,
            value: 'active',
          ),
        ];

        // Act
        final plain = utf8.fuse(base64).decode(state.filtersEncoded!);

        // Assert
        expect(plain, isNot(contains(state.filterGroup)));
        expect(plain, isNot(contains('`')));
        expect(plain.toLowerCase(), isNot(contains('select ')));
      });

      test('should not throw when filters cannot be encoded', () {
        // Arrange — the getter's contract is "a value, never an exception".
        final state = _TestState();
        state.filters = [FilterData(id: 'orphan', operator: null)];

        // Act & Assert
        expect(() => state.filtersEncoded, returnsNormally);
        expect(state.filtersEncoded, isNull);
      });
    });

    group('filtersIncludeSort', () {
      /// Builds a state carrying one real filter and one sort directive.
      _TestState stateWithSort() {
        final state = _TestState();
        state.filters = [
          FilterData(
            id: 'status',
            operator: FilterOperator.equal,
            value: 'active',
          ),
          FilterData(
            id: 'sort',
            operator: FilterOperator.sort,
            value: ['created', 'desc'],
          ),
        ];
        return state;
      }

      test('should default to true', () {
        // Arrange & Act
        final state = _TestState();

        // Assert — existing callers must keep the full round-trip.
        expect(state.filtersIncludeSort, isTrue);
      });

      test('should keep sort in the payload by default', () {
        // Arrange
        final state = stateWithSort();

        // Act
        final restored = FilterHelper.decode(state.filtersEncoded);

        // Assert
        expect(restored.any((e) => e.operator == FilterOperator.sort), isTrue);
      });

      test('should drop sort from the payload when false', () {
        // Arrange
        final state = stateWithSort();
        state.filtersIncludeSort = false;

        // Act
        final restored = FilterHelper.decode(state.filtersEncoded);

        // Assert — the constraint survives, only the directive is removed.
        expect(restored.any((e) => e.operator == FilterOperator.sort), isFalse);
        expect(restored.map((e) => e.id).toList(), ['status']);
      });

      test('should reach the emitted filters query parameter', () {
        // Arrange — the getter is only useful if the flag survives into the map
        // that builds the request URL. Without this the control could pass its
        // own tests while never affecting an outgoing request.
        final state = stateWithSort();
        state.passParameters = true;

        // Act — same state, both settings, so the flag is the only variable.
        final withSort = FilterHelper.decode(
          state.queryParameters['filters']?.first,
        );
        state.filtersIncludeSort = false;
        final withoutSort = FilterHelper.decode(
          state.queryParameters['filters']?.first,
        );

        // Assert
        expect(withSort.any((e) => e.operator == FilterOperator.sort), isTrue);
        expect(
          withoutSort.any((e) => e.operator == FilterOperator.sort),
          isFalse,
        );
        expect(withoutSort.map((e) => e.id).toList(), ['status']);
      });

      test('should not add a sort query parameter of its own', () {
        // Arrange — callers flipping the flag must supply ordering themselves,
        // so this state must not be assumed to emit it.
        final state = stateWithSort();
        state.passParameters = true;
        state.filtersIncludeSort = false;

        // Act
        final parameters = state.queryParameters;

        // Assert — positive control: `filters` proves the map is populated.
        expect(parameters.containsKey('filters'), isTrue);
        expect(parameters.containsKey('sort'), isFalse);
        expect(parameters.containsKey('order'), isFalse);
      });
    });

    group('includeSql', () {
      /// Decoded form of [StateShared.sql] for a single `status = active`
      /// filter, frozen so the default path can be proven byte-identical to the
      /// pre-flag behaviour rather than merely present.
      const canonicalSql = 'select * from `filters` where status = "active" ;';

      /// Builds a state that emits query parameters carrying one filter.
      _TestState stateWithFilter() {
        final state = _TestState();
        state.passParameters = true;
        state.filters = [
          FilterData(
            id: 'status',
            operator: FilterOperator.equal,
            value: 'active',
          ),
        ];
        return state;
      }

      test('should default to true', () {
        // Arrange & Act
        final state = _TestState();

        // Assert — existing callers keep the current request shape.
        expect(state.includeSql, isTrue);
      });

      test('should emit sql decoding to the frozen statement by default', () {
        // Arrange — positive control. An absence test alone would still pass if
        // the parameter had quietly stopped carrying the right statement.
        final state = stateWithFilter();

        // Act
        final parameters = state.queryParameters;

        // Assert
        expect(parameters.containsKey('sql'), isTrue);
        expect(
          utf8.fuse(base64).decode(parameters['sql']!.single),
          canonicalSql,
        );
      });

      test('should omit the sql parameter when false', () {
        // Arrange
        final state = stateWithFilter();
        state.includeSql = false;

        // Act
        final parameters = state.queryParameters;

        // Assert — `filters` is the positive control: the map is populated, so
        // the missing `sql` key is a real omission, not an empty map.
        expect(parameters.containsKey('filters'), isTrue);
        expect(parameters.containsKey('sql'), isFalse);
      });

      test('should leave the sql getter readable when false', () {
        // Arrange — the flag gates emission only, as its documentation claims.
        final state = stateWithFilter();
        state.includeSql = false;

        // Act & Assert
        expect(state.sql, isNotNull);
        expect(utf8.fuse(base64).decode(state.sql!), canonicalSql);
      });

      test('should not disturb the filters payload either way', () {
        // Arrange
        final state = stateWithFilter();

        // Act — same state, both settings, so the flag is the only variable.
        final withSql = state.queryParameters['filters']!.single;
        state.includeSql = false;
        final withoutSql = state.queryParameters['filters']!.single;

        // Assert
        expect(withoutSql, withSql);
      });
    });

    group('SQL path freeze', () {
      test('should still expose the sql getter unchanged', () {
        // Arrange — inventory test. The filters payload was added beside the
        // SQL path, not instead of it; removing capability would be a
        // regression an analyzer and a green suite cannot detect.
        final state = _TestState();
        state.filters = [
          FilterData(
            id: 'status',
            operator: FilterOperator.equal,
            value: 'active',
          ),
        ];

        // Act & Assert — `sql` is base64-encoded, so decode before asserting.
        expect(state.sql, isNotNull);
        final decodedSql = utf8.fuse(base64).decode(state.sql!);
        expect(decodedSql, contains(state.filterGroup));
      });

      test('should still emit both sql and filters query parameters', () {
        // Arrange
        final state = _TestState();
        state.passParameters = true;
        state.filters = [
          FilterData(
            id: 'status',
            operator: FilterOperator.equal,
            value: 'active',
          ),
        ];

        // Act
        final parameters = state.queryParameters;

        // Assert — the two payloads coexist.
        expect(parameters.keys, contains('sql'));
        expect(parameters.keys, contains('filters'));
        expect(parameters['filters']!.single, state.filtersEncoded);
      });
    });
  });
}
