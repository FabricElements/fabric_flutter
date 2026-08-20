import 'package:fabric_flutter/state/state_shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// Concrete [StateShared] that memoizes a deliberately expensive conversion.
///
/// [buildCount] records how often the conversion actually ran so tests can prove
/// a cache hit rather than merely comparing equal results.
class _CachedState extends StateShared {
  /// Counts how many times the conversion body executed.
  int buildCount = 0;

  @override
  List<String> get serialized => cachedSerialize(data, () {
    buildCount++;
    final current = data;
    if (current is! List) return <String>[];
    return current.map((item) => item.toString()).toList();
  });

  /// Exposes the protected invalidation hook to the tests.
  void invalidate() => invalidateSerialized();
}

/// Concrete [StateShared] whose conversion always throws.
class _ThrowingState extends StateShared {
  /// Counts how many times the conversion body executed.
  int buildCount = 0;

  @override
  Object get serialized => cachedSerialize(data, () {
    buildCount++;
    throw StateError('bad payload');
  });
}

void main() {
  group('StateShared.cachedSerialize', () {
    group('cache hits', () {
      test('should build once for repeated reads of the same source', () {
        // Arrange
        final state = _CachedState();
        state.data = ['a', 'b'];

        // Act
        final first = state.serialized;
        final second = state.serialized;
        final third = state.serialized;

        // Assert
        expect(state.buildCount, 1);
        expect(first, ['a', 'b']);
        expect(second, ['a', 'b']);
        expect(third, ['a', 'b']);
      });

      test('should return the identical instance on a cache hit', () {
        // Arrange
        final state = _CachedState();
        state.data = ['a'];

        // Act
        final first = state.serialized;
        final second = state.serialized;

        // Assert
        expect(identical(first, second), isTrue);
      });
    });

    group('cache invalidation', () {
      test('should rebuild when a new source object is assigned', () {
        // Arrange
        final state = _CachedState();
        state.data = ['a'];
        state.serialized;

        // Act
        state.data = ['a', 'b'];
        final result = state.serialized;

        // Assert
        expect(state.buildCount, 2);
        expect(result, ['a', 'b']);
      });

      test('should not rebuild when an equal payload is rejected by data', () {
        // Arrange
        final state = _CachedState();
        state.data = ['a'];
        state.serialized;

        // Act: the data setter ignores a structurally equal payload, so the
        // source reference — and therefore the cache — stays untouched.
        state.data = ['a'];
        final result = state.serialized;

        // Assert
        expect(state.buildCount, 1);
        expect(result, ['a']);
      });

      test('should rebuild after invalidateSerialized', () {
        // Arrange
        final state = _CachedState();
        state.data = ['a'];
        state.serialized;

        // Act
        state.invalidate();
        final result = state.serialized;

        // Assert
        expect(state.buildCount, 2);
        expect(result, ['a']);
      });

      test('should rebuild after clear', () {
        // Arrange
        final state = _CachedState();
        state.data = ['a'];
        state.serialized;

        // Act
        state.clear();
        final result = state.serialized;

        // Assert
        expect(state.buildCount, 2);
        expect(result, isEmpty);
      });
    });

    group('null and empty sources', () {
      test('should build once and cache a null source', () {
        // Arrange
        final state = _CachedState();

        // Act
        final first = state.serialized;
        final second = state.serialized;

        // Assert
        expect(state.buildCount, 1);
        expect(first, isEmpty);
        expect(second, isEmpty);
      });

      test('should cache an empty list source', () {
        // Arrange
        final state = _CachedState();
        state.data = <String>[];

        // Act
        state.serialized;
        state.serialized;

        // Assert
        expect(state.buildCount, 1);
      });

      test('should rebuild when moving from a null source to a real one', () {
        // Arrange
        final state = _CachedState();
        state.serialized;

        // Act
        state.data = ['a'];
        final result = state.serialized;

        // Assert
        expect(state.buildCount, 2);
        expect(result, ['a']);
      });

      test('should rebuild when moving from a real source back to null', () {
        // Arrange
        final state = _CachedState();
        state.data = ['a'];
        state.serialized;

        // Act
        state.data = null;
        final result = state.serialized;

        // Assert
        expect(state.buildCount, 2);
        expect(result, isEmpty);
      });
    });

    group('errors', () {
      test('should propagate the error and leave nothing cached', () {
        // Arrange
        final state = _ThrowingState();
        state.data = ['a'];

        // Act & Assert
        expect(() => state.serialized, throwsStateError);
        expect(() => state.serialized, throwsStateError);
        expect(state.buildCount, 2);
      });
    });
  });
}
