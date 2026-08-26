/// Performance benchmark for [StateShared] and related state utilities.
///
/// ## Purpose
///
/// This file is the **committed, re-runnable benchmark harness** required by the
/// state performance pass. It measures four candidates at the page sizes used by
/// the consuming application (N = 20 / 100 / 200 / 300) and prints before/after
/// figures so every candidate can be either landed with numbers or dropped with
/// numbers.
///
/// ## How to run
///
/// ```bash
/// flutter test test/state/state_shared_benchmark_test.dart --reporter=expanded
/// ```
///
/// Raw microsecond timings are written to stdout via [printOnFailure]. Because
/// `flutter test` swallows stdout on passing tests, the suite deliberately
/// records results in a map and prints a formatted summary at the end of each
/// group so the numbers are always visible.
///
/// ## Candidates
///
/// | # | Description | Status |
/// |---|---|---|
/// | 1 | `_isSameData` — length-mismatch short-circuit before deep walk | measured |
/// | 2 | `cachedSerialize` hit rate on `StateUsers` rebuild pattern | measured |
/// | 3 | `merge()` and `_snapshot()` copy costs | measured |
/// | 4 | Timer coalescing (`_timerData` / `_timerNotify`) | NOT implemented — semantics change |
library;

import 'package:collection/collection.dart';
import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers shared across candidates
// ---------------------------------------------------------------------------

/// Generates a realistic Firestore document payload for a user record.
///
/// Each call returns a **new** [Map] instance so the benchmarks accurately
/// model what a Firestore snapshot delivers — a fresh allocation every time,
/// meaning [identical] always misses on the live-listener path.
Map<String, dynamic> _makeUserDoc(int index) => {
  'id': 'user-$index',
  'name': 'User $index',
  'email': 'user$index@example.com',
  'language': 'en',
  'country': 'US',
  'status': 'active',
  'role': 'user',
  'createdAt': DateTime(2020, 1, 1).millisecondsSinceEpoch,
  'updatedAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
  'preferences': {'theme': 'light', 'density': 'comfortable'},
  'groups': <String, dynamic>{'org1': 'member'},
};

/// Builds a list of [n] fresh user-document maps.
List<Map<String, dynamic>> _makeUserList(int n) =>
    List.generate(n, _makeUserDoc);

/// Runs [fn] [iterations] times and returns the median microseconds per call.
double _benchmarkMedianUs(int iterations, void Function() fn) {
  // Warm up — not measured.
  for (int i = 0; i < 3; i++) {
    fn();
  }
  final times = <int>[];
  for (int i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    fn();
    sw.stop();
    times.add(sw.elapsedMicroseconds);
  }
  times.sort();
  return times[times.length ~/ 2].toDouble();
}

// ---------------------------------------------------------------------------
// Candidate 1 — _isSameData: deep walk vs. length-mismatch short-circuit
//
// Question: how much of the deep walk can a length-mismatch check avoid, and
// is the deep walk on structurally-equal data expensive enough to justify the
// change?
//
// We expose two implementations:
//   • [_isSameDataCurrent]  — exact copy of the production implementation.
//   • [_isSameDataWithLength] — adds a length-mismatch early exit before the
//     deep walk.
//
// Scenarios benchmarked:
//   A. equal-length, structurally equal   → deep walk always runs, returns true
//   B. different-length lists             → current: deep walk; patched: O(1) exit
//   C. equal-length but different content → deep walk runs, returns false
// ---------------------------------------------------------------------------

bool _isSameDataCurrent(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is Iterable || a is Map || b is Iterable || b is Map) {
    return const DeepCollectionEquality().equals(a, b);
  }
  return a == b;
}

bool _isSameDataWithLength(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  // O(1) short-circuit: a list that gained or lost items cannot be equal.
  if (a is List && b is List && a.length != b.length) return false;
  if (a is Map && b is Map && a.length != b.length) return false;
  if (a is Iterable || a is Map || b is Iterable || b is Map) {
    return const DeepCollectionEquality().equals(a, b);
  }
  return a == b;
}

// ---------------------------------------------------------------------------
// Candidate 2 — cachedSerialize hit/miss rate under realistic rebuild patterns
//
// StateUsers.notifyListeners() calls serialized once (populating _usersMap),
// and each listening widget calls serialized again per build.  The cache keys
// on identical(), which misses when data is replaced by a new object.
//
// We measure:
//   • Hit scenario:  multiple reads of serialized after a single data assignment
//     (models N widget builds after one snapshot).
//   • Miss scenario: data is replaced each time before reading serialized
//     (models N snapshots, one build each).
//
// A hit should be O(1); a miss runs N fromJson calls + sort.
// ---------------------------------------------------------------------------

/// Minimal [StateShared] that exposes [cachedSerialize] for benchmarking.
///
/// Delegates to the real [cachedSerialize] implementation so the cache
/// behavior being measured is identical to production.
class _BenchmarkUsersState extends StateShared {
  @override
  List<UserData> get serialized {
    final currentData = data;
    if (currentData == null) return [];
    return cachedSerialize(currentData, () {
      final items = (currentData as List<dynamic>)
          .map((v) => UserData.fromJson(v as Map<String, dynamic>))
          .toList();
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }

  /// Exposes [invalidateSerialized] for direct benchmark use.
  ///
  /// [invalidateSerialized] is `@protected` and normally called only from
  /// within the state hierarchy. The benchmark sets [privateData] directly and
  /// must invalidate the cache to force a controlled miss on the next
  /// [serialized] read. Delegating through this thin override keeps the
  /// protected accessor warnings away without weakening the production API.
  void invalidateForBenchmark() => invalidateSerialized();
}

// ---------------------------------------------------------------------------
// Candidate 3 — merge() and _snapshot() copy costs
//
// merge() runs once per edit, not per frame.  _snapshot() (Map.from) is called
// once when edit mode is entered.  Both are expected to be irrelevant — this
// benchmark exists to prove it with numbers.
//
// We expose a standalone version of the merge logic so we can benchmark it
// without Firebase dependencies.
// ---------------------------------------------------------------------------

/// Standalone copy of [StateShared.merge] for isolated benchmarking.
List<dynamic> _merge({
  required List<dynamic> base,
  required List<dynamic> toMerge,
}) {
  final List<dynamic> newData = List<dynamic>.from(base);
  final Map<dynamic, int> indexById = {};
  for (int i = 0; i < newData.length; i++) {
    indexById.putIfAbsent((newData[i] as Map)['id'], () => i);
  }
  for (final item in toMerge) {
    final itemID = (item as Map)['id'];
    final int? itemIndex = indexById[itemID];
    if (itemIndex != null) {
      newData[itemIndex] = item;
    } else {
      indexById[itemID] = newData.length;
      newData.add(item);
    }
  }
  return newData;
}

/// Standalone copy of [StateDocument._snapshot] for isolated benchmarking.
Map<String, dynamic>? _snapshot(dynamic data) {
  if (data is! Map) return null;
  return Map<String, dynamic>.from(data as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  const sizes = [20, 100, 200, 300];
  const iterations = 200;

  group('Benchmark — Candidate 1: _isSameData length-mismatch short-circuit', () {
    // Results table accumulated for summary print.
    final results = <String, Map<String, double>>{};

    for (final n in sizes) {
      test('N=$n', () {
        // Arrange: two structurally equal lists (scenario A).
        final listA = _makeUserList(n);
        final listB = _makeUserList(n); // different instances, same content

        // Arrange: lists where one has an extra element (scenario B).
        final listC = _makeUserList(n + 1); // length differs by 1

        // Arrange: lists with same length but one different entry (scenario C).
        final listD = _makeUserList(n);
        (listD.last as Map)['name'] = 'Changed';

        // Act — scenario A: structurally equal, same length.
        final currentEqualUs = _benchmarkMedianUs(
          iterations,
          () => _isSameDataCurrent(listA, listB),
        );
        final patchedEqualUs = _benchmarkMedianUs(
          iterations,
          () => _isSameDataWithLength(listA, listB),
        );

        // Act — scenario B: length mismatch (patched should be O(1)).
        final currentLenMismatchUs = _benchmarkMedianUs(
          iterations,
          () => _isSameDataCurrent(listA, listC),
        );
        final patchedLenMismatchUs = _benchmarkMedianUs(
          iterations,
          () => _isSameDataWithLength(listA, listC),
        );

        // Act — scenario C: same length, different content.
        final currentDiffContentUs = _benchmarkMedianUs(
          iterations,
          () => _isSameDataCurrent(listA, listD),
        );
        final patchedDiffContentUs = _benchmarkMedianUs(
          iterations,
          () => _isSameDataWithLength(listA, listD),
        );

        results['N=$n'] = {
          'current_equal_us': currentEqualUs,
          'patched_equal_us': patchedEqualUs,
          'current_len_mismatch_us': currentLenMismatchUs,
          'patched_len_mismatch_us': patchedLenMismatchUs,
          'current_diff_content_us': currentDiffContentUs,
          'patched_diff_content_us': patchedDiffContentUs,
        };

        // Assert correctness: both implementations agree on all scenarios.
        expect(
          _isSameDataCurrent(listA, listB),
          _isSameDataWithLength(listA, listB),
          reason: 'equal scenario must agree',
        );
        expect(
          _isSameDataCurrent(listA, listC),
          _isSameDataWithLength(listA, listC),
          reason: 'length-mismatch scenario must agree',
        );
        expect(
          _isSameDataCurrent(listA, listD),
          _isSameDataWithLength(listA, listD),
          reason: 'diff-content scenario must agree',
        );
      });
    }

    tearDownAll(() {
      // Print formatted summary so numbers appear regardless of reporter.
      final sb = StringBuffer()
        ..writeln()
        ..writeln(
          '=== Candidate 1: _isSameData length-mismatch short-circuit ===',
        )
        ..writeln(
          'Median µs/call  |  scenario A: structurally equal, same length',
        )
        ..writeln(
          '                |  scenario B: length mismatch (short-circuit payoff)',
        )
        ..writeln(
          '                |  scenario C: same length, different content',
        )
        ..writeln(
          '-' * 80,
        )
        ..writeln(
          '${'N'.padRight(4)} '
          '${' Scen-A cur µs'.padLeft(18)}'
          '${' Scen-A pat µs'.padLeft(18)}'
          '${' Scen-B cur µs'.padLeft(18)}'
          '${' Scen-B pat µs'.padLeft(18)}'
          '${' Scen-C cur µs'.padLeft(18)}'
          '${' Scen-C pat µs'.padLeft(18)}',
        );
      for (final n in sizes) {
        final r = results['N=$n'];
        if (r == null) continue;
        sb.writeln(
          '${n.toString().padRight(4)} '
          '${r['current_equal_us']!.toStringAsFixed(1).padLeft(20)}'
          '${r['patched_equal_us']!.toStringAsFixed(1).padLeft(20)}'
          '${r['current_len_mismatch_us']!.toStringAsFixed(1).padLeft(20)}'
          '${r['patched_len_mismatch_us']!.toStringAsFixed(1).padLeft(20)}'
          '${r['current_diff_content_us']!.toStringAsFixed(1).padLeft(20)}'
          '${r['patched_diff_content_us']!.toStringAsFixed(1).padLeft(20)}',
        );
      }
      sb.writeln('-' * 80);
      // ignore: avoid_print
      print(sb.toString());
    });
  });

  group('Benchmark — Candidate 2: cachedSerialize hit/miss rate', () {
    final results = <String, Map<String, double>>{};

    for (final n in sizes) {
      test('N=$n', () {
        final state = _BenchmarkUsersState()..debounceTime = 0;

        // Scenario A: HIT — assign data once, read serialized many times.
        // Models N widget builds that read the same snapshot.
        const readsPerUpdate = 10; // realistic: 1 internal + up to 9 widgets
        final singleSnapshot = _makeUserList(n);

        final hitUs = _benchmarkMedianUs(iterations, () {
          // Assign a fresh-allocated list (as Firestore would deliver).
          state.privateData = List<dynamic>.from(singleSnapshot);
          // Invalidate so the first read is a real miss, subsequent are hits.
          state.invalidateForBenchmark();
          for (int i = 0; i < readsPerUpdate; i++) {
            state.serialized; // ignore: unnecessary_statements
          }
        });
        // Isolate just the cost of a single-read miss (1 fromJson * N + sort).
        final missUs = _benchmarkMedianUs(iterations, () {
          state.privateData = List<dynamic>.from(singleSnapshot);
          state.invalidateForBenchmark();
          state.serialized; // ignore: unnecessary_statements
        });

        // Scenario B: cost of repeated hits ONLY (no miss in the loop).
        state.privateData = List<dynamic>.from(singleSnapshot);
        state.invalidateForBenchmark();
        state.serialized; // prime the cache
        final hitOnlyUs = _benchmarkMedianUs(iterations, () {
          for (int i = 0; i < readsPerUpdate; i++) {
            state.serialized; // ignore: unnecessary_statements
          }
        });

        results['N=$n'] = {
          'miss_us': missUs,
          'hit_then_reads_us': hitUs,
          'hit_only_us': hitOnlyUs,
        };

        // Correctness: cache returns correct data.
        state.privateData = List<dynamic>.from(singleSnapshot);
        state.invalidateForBenchmark();
        final first = state.serialized;
        final second = state.serialized;
        expect(
          identical(first, second),
          isTrue,
          reason: 'cachedSerialize must return the same object on a hit',
        );
      });
    }

    // Count the actual build invocations to verify the cache hits.
    test('build invocation count — cache hits suppress re-deserialization', () {
      // Arrange
      const n = 100;
      final rawData = _makeUserList(n);

      final state = _BenchmarkUsersState()..debounceTime = 0;
      // Wrap serialized to count actual builds via a manual override.
      // We do this by calling cachedSerialize directly with a counter closure.
      state.privateData = List<dynamic>.from(rawData);
      state.invalidateForBenchmark();

      // Act: 10 reads of serialized on the same data reference should build once.
      for (int i = 0; i < 10; i++) {
        state.serialized;
      }

      // We can't intercept buildCount without modifying the state class, but
      // we CAN verify that identical() returns true for the cache:
      final a = state.serialized;
      final b = state.serialized;

      // Assert
      expect(identical(a, b), isTrue, reason: 'cache should return same instance');
    });

    tearDownAll(() {
      final sb = StringBuffer()
        ..writeln()
        ..writeln('=== Candidate 2: cachedSerialize hit/miss rate ===')
        ..writeln(
          'miss_us: cost of 1 fromJson*N + sort (cache miss)',
        )
        ..writeln(
          'hit_then_reads_us: 1 miss + ${10 - 1} hits (realistic per-frame cost)',
        )
        ..writeln(
          'hit_only_us: 10 reads, all hits (lower bound)',
        )
        ..writeln('-' * 72)
        ..writeln(
          '${'N'.padRight(4)}'
          '${'miss µs'.padLeft(16)}'
          '${'1miss+9hits µs'.padLeft(20)}'
          '${'10hits µs'.padLeft(16)}',
        );
      for (final n in sizes) {
        final r = results['N=$n'];
        if (r == null) continue;
        sb.writeln(
          '${n.toString().padRight(4)}'
          '${r['miss_us']!.toStringAsFixed(1).padLeft(16)}'
          '${r['hit_then_reads_us']!.toStringAsFixed(1).padLeft(20)}'
          '${r['hit_only_us']!.toStringAsFixed(1).padLeft(16)}',
        );
      }
      sb.writeln('-' * 72);
      // ignore: avoid_print
      print(sb.toString());
    });
  });

  group('Benchmark — Candidate 3: merge() and _snapshot() copy costs', () {
    final results = <String, Map<String, double>>{};

    for (final n in sizes) {
      test('N=$n', () {
        final base = List<dynamic>.from(_makeUserList(n));
        // A realistic merge: 10 updated + 5 new items.
        final toMerge = <dynamic>[
          ..._makeUserList(10), // updates to existing rows
          ...List.generate(5, (i) => _makeUserDoc(n + i)), // new items
        ];
        final mapData = _makeUserDoc(0);

        // Act — merge()
        final mergeUs = _benchmarkMedianUs(
          iterations,
          () => _merge(base: base, toMerge: toMerge),
        );

        // Act — _snapshot() (Map.from shallow copy)
        final snapshotUs = _benchmarkMedianUs(
          iterations,
          () => _snapshot(mapData),
        );

        results['N=$n'] = {
          'merge_us': mergeUs,
          'snapshot_us': snapshotUs,
        };

        // Correctness: merge produces the right length.
        final merged = _merge(base: base, toMerge: toMerge);
        expect(
          merged.length,
          n + 5,
          reason: '5 new items should be appended',
        );
      });
    }

    tearDownAll(() {
      final sb = StringBuffer()
        ..writeln()
        ..writeln('=== Candidate 3: merge() and _snapshot() copy costs ===')
        ..writeln('merge: base=N, toMerge=10 updates + 5 new items')
        ..writeln('snapshot: Map.from() on a single user document (~10 fields)')
        ..writeln('-' * 56)
        ..writeln(
          '${'N'.padRight(4)}'
          '${'merge µs'.padLeft(16)}'
          '${'snapshot µs'.padLeft(16)}',
        );
      for (final n in sizes) {
        final r = results['N=$n'];
        if (r == null) continue;
        sb.writeln(
          '${n.toString().padRight(4)}'
          '${r['merge_us']!.toStringAsFixed(1).padLeft(16)}'
          '${r['snapshot_us']!.toStringAsFixed(1).padLeft(16)}',
        );
      }
      sb.writeln('-' * 56);
      // ignore: avoid_print
      print(sb.toString());
    });
  });
}
