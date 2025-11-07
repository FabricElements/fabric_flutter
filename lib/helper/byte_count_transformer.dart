import 'dart:async';

/// Stream transformer that limits the total number of bytes emitted by a
/// Stream<List<int>>.
///
/// This transformer is useful when reading potentially large binary streams
/// (for example HTTP responses or file streams) and you want to ensure the
/// consumer does not process more than a specified number of bytes.
///
/// Behavior:
/// - Each incoming chunk's length is added to an internal counter.
/// - If the counter exceeds [maxBytes], the transformer emits an error via
///   the output stream and cancels the upstream subscription. The output
///   stream is then closed.
/// - Otherwise, chunks are forwarded unchanged to the output stream.
/// - Pause, resume and cancel are proxied to the upstream subscription.
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
  /// When the cumulative size of forwarded chunks exceeds this value an
  /// error will be emitted and the upstream subscription will be cancelled.
  final int maxBytes;

  /// Creates a [ByteCountTransformer] that allows up to [maxBytes] bytes
  /// to pass through before emitting an error and closing the stream.
  ByteCountTransformer(this.maxBytes);

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
