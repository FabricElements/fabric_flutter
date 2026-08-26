import 'dart:async';

import 'package:fabric_flutter/state/state_collection.dart';
import 'package:fabric_flutter/state/state_document.dart';
import 'package:flutter_test/flutter_test.dart';

/// [StateDocument] subclass whose [listen] subscribes to an injected
/// [StreamController] rather than Firestore.
///
/// This gives the test direct control over when stream events arrive so it can
/// verify that [dispose] stops them from reaching [StateDocument] callbacks.
class _InMemoryDocument extends StateDocument {
  _InMemoryDocument(this._controller);

  final StreamController<Map<String, dynamic>> _controller;

  /// Counts how many stream events reached the post-dispose callback.
  int received = 0;

  @override
  Future<dynamic> listen() async {
    // Assign to the protected field that StateDocument.dispose() cancels.
    streamSubscription = _controller.stream.listen((event) {
      received++;
      data = event;
    });
    return data;
  }

  @override
  dynamic get serialized => data;
}

/// [StateCollection] subclass that works the same way.
class _InMemoryCollection extends StateCollection {
  _InMemoryCollection(this._controller);

  final StreamController<Map<String, dynamic>> _controller;

  int received = 0;

  @override
  Future<dynamic> listen() async {
    streamSubscription = _controller.stream.listen((event) {
      received++;
      data = event;
    });
    return data;
  }

  @override
  dynamic get serialized => data;
}

void main() {
  group('StateDocument dispose cancels stream subscription', () {
    test(
      'should cancel the subscription so post-dispose events are not received',
      () async {
        // Arrange
        final controller = StreamController<Map<String, dynamic>>();
        final state = _InMemoryDocument(controller);
        await state.listen();
        // Positive control: confirm the subscription is active before dispose.
        controller.add({'id': '1'});
        await Future<void>.delayed(Duration.zero);
        expect(state.received, 1);

        // Act
        state.dispose();

        // Assert — an event added after dispose must not reach the callback.
        // Without the dispose() fix, the subscription stays alive and the
        // callback would increment received to 2.
        controller.add({'id': '2'});
        await Future<void>.delayed(Duration.zero);
        expect(state.received, 1);

        await controller.close();
      },
    );

    test('should not throw when no subscription is active', () {
      // Arrange — positive control: dispose must not throw when listen() was
      // never called, e.g. when only the one-shot call() was used.
      final controller = StreamController<Map<String, dynamic>>();
      final state = _InMemoryDocument(controller);

      // Act & Assert
      expect(() => state.dispose(), returnsNormally);

      controller.close();
    });
  });

  group('StateCollection dispose cancels stream subscription', () {
    test(
      'should cancel the subscription so post-dispose events are not received',
      () async {
        // Arrange
        final controller = StreamController<Map<String, dynamic>>();
        final state = _InMemoryCollection(controller);
        await state.listen();
        controller.add({'id': '1'});
        await Future<void>.delayed(Duration.zero);
        expect(state.received, 1);

        // Act
        state.dispose();

        // Assert
        controller.add({'id': '2'});
        await Future<void>.delayed(Duration.zero);
        expect(state.received, 1);

        await controller.close();
      },
    );

    test('should not throw when no subscription is active', () {
      // Arrange
      final controller = StreamController<Map<String, dynamic>>();
      final state = _InMemoryCollection(controller);

      // Act & Assert
      expect(() => state.dispose(), returnsNormally);

      controller.close();
    });
  });
}
