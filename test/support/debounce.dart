import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waits out the widest debounce window [StateShared] can select.
///
/// [StateShared] coalesces updates behind a trailing-edge timer, so a publish
/// is never synchronous with the assignment that triggered it. The widest
/// window is [StateShared.debounceTimeNotInitialized] (500ms), used until a
/// first successful load marks the state initialized; waiting slightly longer
/// guarantees any pending publish has already landed.
///
/// Tests await this instead of taking a synchronous shortcut, so they observe
/// exactly the delivery a consumer observes in production.
Future<void> settleDebounce() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

/// Waits out the debounce window of a state that has finished its first load.
///
/// Once [StateShared.initialized] is `true` the window narrows to
/// [StateShared.debounceTime] (10ms by default), with a 50ms floor on the first
/// call of a burst. Use this for tests that model the steady state, where it is
/// far cheaper than [settleDebounce].
Future<void> settleDebounceInitialized() =>
    Future<void>.delayed(const Duration(milliseconds: 120));

/// Advances a widget test past every debounce window a [StateShared] can pick.
///
/// A widget test runs on a fake clock, so a plain `await` never fires the
/// trailing-edge timer — the test would end with the timer still pending and
/// fail. Pumping twice covers the two-stage delivery that any batched read
/// produces: the first pump fires the scheduling timer and lets the awaited
/// fetch complete, the second waits out the debounce the resulting assignment
/// starts.
Future<void> pumpDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}
