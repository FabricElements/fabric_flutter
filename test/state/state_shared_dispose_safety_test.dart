// Tests for four post-dispose lifecycle defects in StateShared.
//
// Each group targets one defect:
//   D-1  notifyListeners() after dispose creates an uncancellable Timer whose
//        callback calls super.notifyListeners() on a disposed ChangeNotifier.
//   D-2  error setter and _publishData call sink.add on closed
//        StreamControllers after dispose ("Bad state: Cannot add event after
//        closing").
//   D-3  applyFilters(fetch: true) schedules a Future.delayed callback that
//        calls call() with no disposed guard, unlike the adjacent redirect path
//        which correctly guards with context.mounted.
//   D-4  When debounceTime <= 0, notifyListeners() and _publishData() call
//        super.notifyListeners() synchronously.  If any code path reads a
//        [serialized] getter during a widget rebuild and that getter sets
//        [error] or [data], the synchronous dispatch marks the listening
//        Provider scope element dirty mid-build and Flutter throws
//        "setState() or markNeedsBuild() called during build."
//
// Every test expresses the CORRECT post-fix behavior (returnsNormally / no
// error).  Before the fix these tests fail because the operations throw.

import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

/// [StateShared] with debounce disabled so notifications are delivered
/// synchronously; used for tests that need a direct, non-timer throw path.
class _ImmediateState extends StateShared {
  @override
  int get debounceTime => 0;

  @override
  dynamic get serialized => data;

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async => null;
}

/// [StateShared] with default debouncing; used for timer-path tests where the
/// defects manifest only after the debounce window expires.
///
/// [call] sets [data] so the data-publish path (stream sink + ChangeNotifier)
/// is exercised in addition to the direct notifyListeners path.
class _DebouncedState extends StateShared {
  int callCount = 0;

  @override
  dynamic get serialized => data;

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    callCount++;
    // Setting data triggers _notifyData → debounce timer → _publishData →
    // _controllerStream.sink.add + super.notifyListeners, both of which throw
    // on a disposed object without the fix.
    data = {'called': callCount};
    return data;
  }
}

/// [StateShared] with debounce disabled whose [serialized] getter sets [error]
/// on every read. Models a payload-validation getter that records a validation
/// error on bad input.
///
/// Tests use [ChangeNotifierProvider] so the Provider scope element (already
/// built, _dirty = false) receives [markNeedsBuild()] while [_debugBuilding] is
/// still true — the exact invariant Flutter asserts on. [ListenableBuilder]
/// does not reproduce this because its own state element is still dirty during
/// the initial build, making [markNeedsBuild()] a no-op in that phase.
///
/// The [error] setter's change-guard (if (_error == message) return) ensures
/// the second and later reads do not re-notify, breaking the potential loop.
class _ImmediateBuildError extends StateShared {
  /// Counts how many times [serialized] has been evaluated during widget builds.
  int rebuildCount = 0;

  @override
  int get debounceTime => 0;

  @override
  dynamic get serialized {
    rebuildCount++;
    error = 'payload error';
    return data;
  }

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async => null;
}

/// Control for D-4: same [serialized] pattern with default debouncing.
///
/// The debounce timer naturally defers the notification past the build phase.
/// The same code that crashes with [_ImmediateBuildError] must be safe here.
/// Both halves must appear in the D-4 red run: the control passing isolates
/// the fault to the immediate path.
class _DebouncedBuildError extends StateShared {
  int rebuildCount = 0;

  @override
  dynamic get serialized {
    rebuildCount++;
    error = 'payload error';
    return data;
  }

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async => null;
}

/// [StateShared] with debounce disabled; the [serialized] getter sets [data]
/// on the first read, exercising the [_publishData] synchronous path rather
/// than the [notifyListeners] path tested by [_ImmediateBuildError].
class _ImmediateDataDuringBuild extends StateShared {
  bool _dataSet = false;

  @override
  int get debounceTime => 0;

  @override
  dynamic get serialized {
    if (!_dataSet) {
      _dataSet = true;
      // data setter → _notifyData() → _publishData() → super.notifyListeners()
      data = {'key': 'value'};
    }
    return data;
  }

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async => null;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('StateShared post-dispose safety', () {
    // ── D-1: notifyListeners after dispose ──────────────────────────────────
    group('D-1 notifyListeners after dispose', () {
      test(
        'should not throw when notifyListeners is called synchronously after '
        'dispose (debounceTime = 0)',
        () {
          // Arrange
          final state = _ImmediateState();
          state.dispose();

          // Act & Assert — with debounceTime=0 super.notifyListeners() is called
          // synchronously on a disposed ChangeNotifier; without the fix it trips
          // debugAssertNotDisposed and throws FlutterError.
          expect(() => state.notifyListeners(), returnsNormally);
        },
      );

      testWidgets(
        'should not throw when notifyListeners is called after dispose and its '
        'debounce timer fires',
        (tester) async {
          // Arrange
          final state = _DebouncedState();

          // Act — dispose FIRST, then call notifyListeners.  dispose() cancels
          // any timer already in flight, but a timer created AFTER dispose() has
          // already run can never be cancelled.
          state.dispose();
          state.notifyListeners();

          // Assert — pump advances the fake clock past the 500 ms
          // debounceTimeNotInitialized window.  Without the fix the timer
          // callback calls super.notifyListeners() on a disposed ChangeNotifier
          // and throws a FlutterError.
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    });

    // ── D-2: closed-sink throws after dispose ───────────────────────────────
    group('D-2 closed-sink guard', () {
      test(
        'should not throw when error is set on a disposed state '
        '(closed error-stream sink)',
        () {
          // Arrange — debounced state so notifyListeners() schedules a timer
          // rather than throwing synchronously, isolating the sink.add issue.
          final state = _DebouncedState();
          state.dispose();

          // Act & Assert — _controllerStreamError.sink.add is called
          // synchronously inside the error setter; without the fix it throws
          // "Bad state: Cannot add new events after calling close".
          expect(() => state.error = 'post-dispose error', returnsNormally);
        },
      );

      testWidgets(
        'should not throw when data is set after dispose and its publish timer '
        'fires (closed data-stream sink)',
        (tester) async {
          // Arrange
          final state = _DebouncedState();
          state.dispose();

          // Act — assigning data schedules a _notifyData debounce timer.
          state.data = {'key': 'value'};

          // Assert — pump fires the debounce timer; _publishData calls
          // _controllerStream.sink.add on the closed controller.  Without the
          // fix this throws "Bad state: Cannot add new events after calling close".
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    });

    // ── D-3: applyFilters fetch callback is unguarded ───────────────────────
    group('D-3 applyFilters fetch callback', () {
      testWidgets(
        'should not throw when dispose fires during the 400 ms fetch delay',
        (tester) async {
          // Arrange
          final state = _DebouncedState();

          // Act — applyFilters(fetch: true) schedules Future.delayed(400 ms)
          // that will call call(); dispose before the delay expires.
          state.applyFilters([], fetch: true);
          state.dispose();

          // Assert — first pump fires the 400 ms delay, running call() which
          // sets data and schedules a _notifyData debounce timer (500 ms, since
          // the state was never initialized).  Without the fix this chain
          // eventually calls sink.add on the closed data-stream controller.
          await tester.pump(const Duration(milliseconds: 401));
          // Second pump fires the _notifyData debounce timer.  Without the fix
          // _publishData throws "Bad state: Cannot add new events after calling
          // close".
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    });

    // ── D-4: immediate notify dispatched during build phase ─────────────────
    //
    // When debounceTime <= 0 two dispatch paths call super.notifyListeners()
    // synchronously:
    //   notifyListeners()   — entered from the error setter
    //   _publishData()      — entered from the data setter via _notifyData()
    //
    // If a [serialized] getter sets [error] or [data] during a widget build,
    // this synchronous dispatch calls markNeedsBuild() on the Provider scope
    // element (which is already built, _dirty = false) while _debugBuilding is
    // still true. Flutter asserts on this: "setState() called during build."
    //
    // Tests use ChangeNotifierProvider + Builder because ListenableBuilder does
    // not reproduce the crash: its own state element is still dirty (_dirty =
    // true) during the initial build so markNeedsBuild() returns early without
    // hitting the assert. The Provider scope element, built before the consumer
    // element, has _dirty = false when the notification fires.
    group('D-4 immediate notify during build phase', () {
      testWidgets(
        'debounced control: setting error during build should not throw '
        '(timer defers past build phase; proves fault is specific to '
        'immediate path)',
        (tester) async {
          // Arrange — default debounce; notification is deferred by a timer so
          // it lands outside the build phase.
          final state = _DebouncedBuildError();

          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: state,
              child: Builder(
                builder: (context) {
                  context.watch<_DebouncedBuildError>().serialized;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          // Fire the debounce timer; it runs outside the build phase and must
          // not throw.
          await tester.pump(const Duration(milliseconds: 600));
          state.dispose();
        },
      );

      testWidgets(
        'should not throw when debounceTime = 0 and error is set during build '
        '(notifyListeners immediate path must defer to post-frame)',
        (tester) async {
          // Arrange — immediate path; the error setter calls notifyListeners()
          // which reaches super.notifyListeners() synchronously during build.
          // Without the fix: "setState() or markNeedsBuild() called during
          // build."
          final state = _ImmediateBuildError();

          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: state,
              child: Builder(
                builder: (context) {
                  context.watch<_ImmediateBuildError>().serialized;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          // Pump one frame so the deferred post-frame callback fires.
          await tester.pump();
          state.dispose();
        },
      );

      testWidgets(
        'should not throw when debounceTime = 0 and data is set during build '
        '(_publishData immediate path must defer to post-frame)',
        (tester) async {
          // Arrange — data setter → _notifyData → _publishData →
          // super.notifyListeners() synchronously during build.  Same
          // build-phase hazard, different entry point.
          // Without the fix: "setState() or markNeedsBuild() called during
          // build."
          final state = _ImmediateDataDuringBuild();

          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: state,
              child: Builder(
                builder: (context) {
                  context.watch<_ImmediateDataDuringBuild>().serialized;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          await tester.pump();
          state.dispose();
        },
      );

      testWidgets(
        'should settle after exactly one extra rebuild when a persistent error '
        'is set during build (no infinite-notification loop)',
        (tester) async {
          // Arrange — the error setter is change-guarded: the second build
          // yields the same string, the setter returns early without notifying,
          // and the loop terminates.
          final state = _ImmediateBuildError();

          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: state,
              child: Builder(
                builder: (context) {
                  context.watch<_ImmediateBuildError>().serialized;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          // pumpAndSettle must complete rather than time out.  A loop would
          // cause it to hit the default frame limit and throw.
          await tester.pumpAndSettle();

          // Rebuild 1 = initial build (error deferred via addPostFrameCallback)
          // Rebuild 2 = triggered by the deferred notification; error is already
          //             set, change-guard returns early, no further notification
          expect(state.rebuildCount, 2);
          state.dispose();
        },
      );
    });
  });
}

