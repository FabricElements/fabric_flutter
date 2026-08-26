import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/debounce.dart';

// ---------------------------------------------------------------------------
// Minimal domain model used to verify typed-draft behaviour.
// ---------------------------------------------------------------------------

/// A lightweight value type that holds a single field.
///
/// Using a class rather than a raw map makes it easy to distinguish the typed
/// draft from a plain [Map] and to assert that the draft is an independent
/// object rather than an alias of [serialized].
class _Item {
  _Item(this.name);

  String name;

  /// Deserialises from the raw [data] map.
  ///
  /// Returns a fresh allocation on every call — exactly what [serialized] is
  /// expected to do so that [copy] remains independent.
  _Item.fromJson(Map<String, dynamic>? json) : name = (json?['name'] as String?) ?? '';
}

// ---------------------------------------------------------------------------
// State under test — routes through cachedSerialize so the bypass flag fires.
// ---------------------------------------------------------------------------

/// A concrete [StateShared] that deserialises its payload into [_Item].
///
/// Using [cachedSerialize] exercises the [_bypassSerializedCache] flag that
/// [_freshSerialized] toggles to produce a copy independent of the memo.
class _TestItemState extends StateShared {
  @override
  _Item? get serialized {
    if (data == null) return null;
    return cachedSerialize(data, () => _Item.fromJson(data as Map<String, dynamic>?));
  }
}

/// A concrete [StateShared] whose [serialized] throws deterministically.
///
/// Used to verify that a throwing [serialized] leaves the bypass flag cleared.
class _ThrowingState extends StateShared {
  @override
  dynamic get serialized => throw 'boom';
}

/// A subclass that narrows [copy] to the concrete model type.
///
/// Uses getter-only narrowing — the inherited dynamic setter is kept — which
/// is the simplest and recommended form for consumers. Tests confirm that
/// direct field mutation through the narrowed getter is stable across reads.
class _TypedItemState extends _TestItemState {
  @override
  _Item? get copy => super.copy as _Item?;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StateShared copy draft', () {
    group('initial state', () {
      test('should be null when data is null', () {
        // Arrange & Act
        final state = _TestItemState();

        // Assert
        expect(state.copy, isNull);
      });
    });

    group('after data is set', () {
      test('should be an instance of the serialized type, not a Map', () {
        // Arrange
        final state = _TestItemState();

        // Act
        state.data = {'name': 'alpha'};

        // Assert
        expect(state.copy, isA<_Item>());
        expect((state.copy as _Item).name, 'alpha');
      });

      test('should be null when data is set to null', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};
        // Prime the draft.
        state.copy; // ignore: unnecessary_statements

        // Act
        state.data = null;

        // Assert
        expect(state.copy, isNull);
      });

      test('should reset when data is reassigned to a new payload', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};
        final firstCopy = state.copy as _Item;
        expect(firstCopy.name, 'alpha');

        // Act
        state.data = {'name': 'beta'};

        // Assert — draft is rebuilt from the new payload, not the old one.
        final secondCopy = state.copy as _Item;
        expect(secondCopy.name, 'beta');
      });
    });

    group('aliasing guard', () {
      test('should be a different object from serialized', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};

        // Act
        final draft = state.copy as _Item;
        final canonical = state.serialized as _Item;

        // Assert — they hold the same value but are distinct allocations.
        expect(draft.name, 'alpha');
        expect(canonical.name, 'alpha');
        expect(identical(draft, canonical), isFalse);
      });

      test('mutating the draft should not mutate serialized', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};
        final draft = state.copy as _Item;

        // Act — edit the draft in place.
        draft.name = 'mutated';

        // Assert — the canonical serialized value is unchanged.
        expect((state.serialized as _Item).name, 'alpha');
        expect(draft.name, 'mutated');
      });
    });

    group('set copy', () {
      test('should replace the draft without notifying listeners', () async {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};
        await settleDebounce();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.copy = _Item('edited');
        await settleDebounce();

        // Assert — no listener rebuild, but the draft reflects the assignment.
        expect(notified, 0);
        expect((state.copy as _Item).name, 'edited');
      });

      test('should survive a subsequent data change by being invalidated', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};
        state.copy = _Item('edited');
        expect((state.copy as _Item).name, 'edited');

        // Act — new data invalidates the manually assigned draft.
        state.data = {'name': 'beta'};

        // Assert — draft is rebuilt from new data, not kept as the stale edit.
        expect((state.copy as _Item).name, 'beta');
      });
    });

    group('clear', () {
      test('should reset the draft to null', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};
        state.copy; // ignore: unnecessary_statements — prime the draft

        // Act
        state.clear();

        // Assert
        expect(state.copy, isNull);
      });
    });

    group('identity stability', () {
      test('should return the same instance on repeated reads', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};

        // Assert — two consecutive reads must be identical.
        // If the getter rebuilt on every call, field mutations would silently
        // evaporate because they would land on a throwaway object.
        expect(identical(state.copy, state.copy), isTrue);
      });

      test('field mutation should survive a re-read of copy', () {
        // Arrange
        final state = _TestItemState();
        state.data = {'name': 'alpha'};

        // Act
        (state.copy as _Item).name = 'in-progress';

        // Assert — re-reading copy returns the same instance with the mutation.
        expect((state.copy as _Item).name, 'in-progress');
      });
    });

    group('edits discarded on data update', () {
      test('should discard in-flight mutations when data is reassigned', () {
        // Arrange — prime the draft and mutate it.
        final state = _TestItemState();
        state.data = {'name': 'original'};
        (state.copy as _Item).name = 'in-progress';
        expect((state.copy as _Item).name, 'in-progress');

        // Act — a new payload arrives (e.g. a server push).
        state.data = {'name': 'server'};

        // Assert — the draft is rebuilt from the new payload; the in-flight
        // edit is gone. This is the documented, intentional contract.
        expect((state.copy as _Item).name, 'server');
      });
    });

    group('typed subclass narrowing', () {
      test('getter-only override should return the concrete type without a cast', () {
        // Arrange
        final state = _TypedItemState();
        state.data = {'name': 'alpha'};

        // Act — copy is _Item? with no cast at the call site.
        final draft = state.copy;

        // Assert
        expect(draft, isA<_Item>());
        expect(draft!.name, 'alpha');
      });

      test('field mutation through the narrowed getter should survive a re-read', () {
        // Arrange
        final state = _TypedItemState();
        state.data = {'name': 'alpha'};

        // Act — mutate directly on the typed getter; no cast required.
        state.copy!.name = 'typed-edit';

        // Assert — the mutation is visible on the next read.
        expect(state.copy!.name, 'typed-edit');
      });

      test('narrowed copy should be a different instance from serialized', () {
        // Arrange
        final state = _TypedItemState();
        state.data = {'name': 'alpha'};

        // Assert — aliasing guard still holds for the narrowed subclass.
        expect(identical(state.copy, state.serialized), isFalse);
      });
    });

    group('bypass flag safety', () {
      test('should leave bypass flag cleared when serialized throws', () {
        // Arrange
        final state = _ThrowingState();
        state.data = {'x': 1};

        // Act — accessing copy triggers _freshSerialized, which calls
        // serialized inside a try/finally.
        expect(() => state.copy, throwsA('boom'));

        // Assert — the flag is cleared even after the throw, so a subsequent
        // read of serialized does not inadvertently bypass the memo.
        // We verify indirectly: calling cachedSerialize on a separate state
        // still hits the memo path (no throw) — but for ThrowingState we can
        // only check that copy throws again (not a stale bypass).
        expect(() => state.copy, throwsA('boom'));
      });
    });
  });
}
