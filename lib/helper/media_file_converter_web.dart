/// Web implementation of the media file converter.
///
/// Browsers that run on Apple hardware decode HEIC/HEIF in the platform image
/// pipeline, which makes the browser the only portable decoder a Flutter web
/// app has for those containers. The conversion decodes the raw bytes into an
/// image bitmap, draws the bitmap on a canvas, and re-encodes it as JPEG — a
/// format every upload backend and downstream consumer in the pipeline
/// accepts. Where the browser itself cannot decode the container (Chrome and
/// Firefox on most hardware), the decode promise rejects, which the converter
/// reports as an unsupported conversion so callers can reject the file with a
/// clear message instead of staging bytes a later upload would refuse.
library;

import 'dart:async' show TimeoutException;
import 'dart:convert' show base64Decode;
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'drop_file_format.dart';
import 'media_file_converter_native.dart'
    show
        MediaConversionResult,
        MediaFileConverter,
        mediaConversionTimeout,
        withJpegExtension;

/// The MIME type the converter re-encodes converted images to.
const String _jpegMimeType = 'image/jpeg';

/// Converts HEIC/HEIF photo files to JPEG through the browser's image decoder.
///
/// Uses a canvas re-encode rather than an in-process image package because no
/// pure-Dart HEIC decoder exists in the dependency tree, and adding one would
/// add a large unvetted dependency for a container the browser already
/// understands on the platforms where it occurs.
class MediaFileConverterImpl extends MediaFileConverter {
  /// Creates a converter using the current browser environment.
  const MediaFileConverterImpl();

  /// Decodes [file]'s bytes into a bitmap and re-encodes them as JPEG through
  /// a canvas.
  ///
  /// A rejected decode promise means the browser cannot decode the container,
  /// which is the expected outcome on browsers without platform HEIC support.
  @override
  Future<MediaConversionResult> convert(DropZoneFile file) async {
    if (!MediaFileConverter.needsConversion(
      mimeType: file.mimeType,
      fileName: file.name,
    )) {
      return MediaConversionResult(file: file);
    }

    final blob = web.Blob([file.bytes.toJS].toJS);
    web.ImageBitmap bitmap;
    try {
      bitmap = await web.window
          .createImageBitmap(blob)
          .toDart
          .timeout(mediaConversionTimeout);
    } on TimeoutException {
      return const MediaConversionResult.unsupported('conversion-timeout');
    } catch (_) {
      return const MediaConversionResult.unsupported('decode-failed');
    }
    try {
      final canvas = web.HTMLCanvasElement()
        ..width = bitmap.width
        ..height = bitmap.height;
      final context = canvas.getContext('2d');
      if (context == null) {
        return const MediaConversionResult.unsupported('encode-failed');
      }
      (context as web.CanvasRenderingContext2D).drawImage(bitmap, 0, 0);
      final dataUrl = canvas.toDataURL(_jpegMimeType);
      // A canvas that cannot produce the requested type silently falls back to
      // PNG, so the returned prefix is the authoritative answer.
      if (!dataUrl.startsWith('data:image/jpeg')) {
        return const MediaConversionResult.unsupported('encode-failed');
      }
      final bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
      return MediaConversionResult(
        file: DropZoneFile(
          bytes: bytes,
          name: withJpegExtension(file.name),
          size: bytes.lengthInBytes,
          mimeType: _jpegMimeType,
        ),
      );
    } finally {
      bitmap.close();
    }
  }
}
