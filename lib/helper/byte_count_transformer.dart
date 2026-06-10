import 'dart:async';

/// Stream transformer that limits the total number of bytes emitted by a
/// `Stream<List<int>>`.
///
/// This transformer is useful when reading potentially large binary streams
/// such as HTTP responses or file streams and you want to ensure the consumer
/// does not process more than a specified number of bytes.
///
/// Behavior:
/// - Each incoming chunk's length is added to an internal counter.
/// - If the counter exceeds [maxBytes], the transformer emits an error via the
///   output stream, cancels the upstream subscription, and then closes.
/// - Otherwise, chunks are forwarded unchanged.
/// - Pause, resume, and cancel are proxied to the upstream subscription.
///
/// Example:
/// ```dart
/// final limited = sourceStream.transform(ByteCountTransformer(1024));
/// limited.listen(
///   (chunk) => print('got ${chunk.length} bytes'),
///   onError: (e) => print('stream error: $e'),
///   onDone: () => print('done'),
/// );
/// ```
class ByteCountTransformer extends StreamTransformerBase<List<int>, List<int>> {
  /// Maximum total bytes allowed to be forwarded by the transformer.
  ///
  /// When the cumulative size of forwarded chunks exceeds this value, an error
  /// is emitted and the upstream subscription is cancelled.
  final int maxBytes;

  /// Creates a [ByteCountTransformer] capped at [maxBytes] bytes.
  ByteCountTransformer(this.maxBytes);

  /// Returns a stream that forwards bytes until [maxBytes] is exceeded.
  ///
  /// Once the limit is crossed, the returned stream emits an [Exception],
  /// cancels the source subscription, and closes so callers can fail fast when
  /// handling unexpectedly large payloads.
  @override
  Stream<List<int>> bind(Stream<List<int>> stream) {
    late StreamController<List<int>> controller;
    late StreamSubscription<List<int>> subscription;
    controller = StreamController<List<int>>(
      onListen: () {
        int count = 0;
        subscription = stream.listen(
          (chunk) {
            count += chunk.length;
            if (count > maxBytes) {
              controller.addError(
                Exception('Response exceeds allowed size of $maxBytes bytes'),
              );
              // stop reading further bytes
              subscription.cancel();
              controller.close();
              return;
            }
            controller.add(chunk);
          },
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: true,
        );
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () => subscription.cancel(),
    );
    return controller.stream;
  }
}
