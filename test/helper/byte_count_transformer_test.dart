import 'dart:async';

import 'package:fabric_flutter/helper/byte_count_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ByteCountTransformer', () {
    test('should forward chunks unchanged while under the limit', () async {
      // Arrange
      final source = Stream<List<int>>.fromIterable([
        [1, 2, 3],
        [4, 5],
      ]);

      // Act
      final result = await source
          .transform(ByteCountTransformer(10))
          .toList();

      // Assert
      expect(result, [
        [1, 2, 3],
        [4, 5],
      ]);
    });

    test('should emit an error once the byte limit is exceeded', () async {
      // Arrange
      final source = Stream<List<int>>.fromIterable([
        [1, 2, 3],
        [4, 5, 6, 7],
      ]);

      // Act
      final emitted = <List<int>>[];
      Object? error;
      final completer = Completer<void>();
      source.transform(ByteCountTransformer(5)).listen(
        emitted.add,
        onError: (Object e) {
          error = e;
        },
        onDone: completer.complete,
      );
      await completer.future;

      // Assert
      expect(emitted, [
        [1, 2, 3],
      ]);
      expect(error, isA<Exception>());
    });

    test('should allow chunks summing exactly to the limit', () async {
      // Arrange
      final source = Stream<List<int>>.fromIterable([
        [1, 2, 3, 4],
      ]);

      // Act
      final result = await source
          .transform(ByteCountTransformer(4))
          .toList();

      // Assert
      expect(result, [
        [1, 2, 3, 4],
      ]);
    });
  });
}
