/// Native implementation of the media file converter.
///
/// HEIC/HEIF photos reach the drop zone on platforms whose gallery produces
/// them by default, but most upload backends refuse those containers. The
/// Flutter engine already ships a platform image decoder — ImageIO on iOS and
/// the platform bitmap decoder on Android — which this converter drives
/// through `instantiateImageCodec` to decode the container, and the pure-Dart
/// `image` package then re-encodes the decoded pixels as JPEG off the UI
/// thread. When the platform cannot decode the container — Android without a
/// HEIF decoder, or a corrupt file — the conversion is reported as
/// unsupported so callers reject the file with a clear message instead of
/// staging bytes a later upload would refuse.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'drop_file_format.dart';

/// The MIME type the converter re-encodes converted images to.
const String _jpegMimeType = 'image/jpeg';

/// The file extension matching [_jpegMimeType].
const String _jpegExtension = 'jpg';

/// How long a single conversion may run before it is reported as failed.
///
/// The deadline covers the platform decode and the re-encode together so a
/// hung codec can never leave a drop unresolved; the caller always receives a
/// result and can surface its in-zone warning.
const Duration mediaConversionTimeout = Duration(seconds: 30);

/// The largest decoded image, in pixels, the converter will re-encode.
///
/// A decoder can report enormous dimensions for a corrupt or hostile
/// container, and the re-encode allocates several bytes per pixel, so
/// oversized images are rejected instead of exhausting memory.
const int _maxPixels = 40 << 20; // 40 MP

/// The JPEG encoding quality for converted photos.
///
/// Mirrors the quality the media helper already uses for its re-encodes so
/// converted photos match the rest of the pipeline.
const int _jpegQuality = 95;

/// The result of attempting to convert a media file.
@immutable
class MediaConversionResult {
  /// Creates a conversion outcome from the converted [file], when there is
  /// one, carrying the internal [reason] for the outcome.
  const MediaConversionResult({this.file, this.reason});

  /// Creates a conversion outcome reporting that [reason] could not be fixed.
  const MediaConversionResult.unsupported(this.reason) : file = null;

  /// The converted file payload, or `null` when the conversion failed.
  final DropZoneFile? file;

  /// A short, non-sensitive identifier for why the conversion failed.
  final String? reason;
}

/// Converts dropped or picked media files to upload-safe formats where needed.
///
/// The class is a platform seam: the web implementation re-encodes through the
/// browser's image decoder, and this native implementation decodes through the
/// engine's platform codec and re-encodes through the pure-Dart `image`
/// package. The public contract is shared so callers write the same code on
/// every platform.
abstract class MediaFileConverter {
  /// Creates a converter.
  ///
  /// Constant so a default converter instance can be a compile-time constant
  /// shared by every drop-zone state.
  const MediaFileConverter();

  /// Returns whether [mimeType] or [fileName] names a container this converter
  /// converts before upload.
  ///
  /// The check is format-based rather than platform-based so the drop zone can
  /// explain a rejection even on platforms that cannot convert.
  static bool needsConversion({String? mimeType, required String fileName}) {
    final container = _containerOf(mimeType: mimeType, fileName: fileName);
    return container != null;
  }

  /// Resolves the container identifier of a file that needs a conversion, or
  /// `null` when the file does not need one.
  ///
  /// Callers use the returned name in user-facing copy, so it is the plain
  /// lowercase format name rather than a MIME type or an extension.
  static String? _containerOf({String? mimeType, required String fileName}) {
    if (mimeType != null) {
      final lower = mimeType.toLowerCase();
      if (lower == 'image/heic' || lower == 'image/heif') return 'heic';
      if (lower == 'image/heic-sequence' || lower == 'image/heif-sequence') {
        return 'heic';
      }
    }
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    final extension = fileName.substring(dot + 1).toLowerCase();
    if (extension == 'heic' || extension == 'heif') return 'heic';
    return null;
  }

  /// Converts [file] when its container requires it.
  ///
  /// Returns a [MediaConversionResult] whose [MediaConversionResult.file] is
  /// the original payload when no conversion is needed, or the converted
  /// payload when the conversion succeeded. When the conversion is required
  /// but cannot be performed — no platform decoder available, the decode
  /// failed, or the conversion exceeded its deadline — the result carries
  /// [MediaConversionResult.reason] instead, and the caller must not stage
  /// the file. The method never throws and never leaves the returned future
  /// unresolved.
  Future<MediaConversionResult> convert(DropZoneFile file);
}

/// The platform converter used on iOS, Android, and desktop.
///
/// Files that need no conversion pass through unchanged. A file whose
/// container requires a conversion is decoded by the engine's platform image
/// codec and re-encoded as JPEG off the UI thread; when the platform cannot
/// decode the container — or anything else in the pipeline fails — the file is
/// reported as unsupported rather than staged as-is, because the raw bytes of
/// those containers would otherwise only fail later, at upload time, after
/// the user has already moved on.
class MediaFileConverterImpl extends MediaFileConverter {
  /// Creates the native converter.
  ///
  /// The deadline is injectable so tests can exercise the timeout path
  /// without waiting the production duration.
  const MediaFileConverterImpl({this.timeout = mediaConversionTimeout});

  /// How long a single conversion may run before it is reported as failed.
  final Duration timeout;

  /// Passes [file] through, or converts it when its container requires it.
  ///
  /// The whole conversion runs inside one deadline and one try/catch so any
  /// failure — decode, encode, timeout, or engine error — resolves to an
  /// unsupported result the caller can turn into its in-zone warning.
  @override
  Future<MediaConversionResult> convert(DropZoneFile file) {
    if (!MediaFileConverter.needsConversion(
      mimeType: file.mimeType,
      fileName: file.name,
    )) {
      return Future.value(MediaConversionResult(file: file));
    }
    return _convert(file)
        .timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException('media conversion', mediaConversionTimeout);
          },
        )
        .catchError((Object _) {
          return const MediaConversionResult.unsupported('decode-failed');
        });
  }

  /// Decodes [file] through the engine codec and re-encodes it as JPEG.
  static Future<MediaConversionResult> _convert(DropZoneFile file) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(file.bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final width = image.width;
      final height = image.height;
      if (width <= 0 || height <= 0 || width * height > _maxPixels) {
        return const MediaConversionResult.unsupported('image-too-large');
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        return const MediaConversionResult.unsupported('encode-failed');
      }
      // The pure-Dart re-encode is synchronous byte work, so it runs off the
      // UI thread; only plain, transferable values cross the boundary.
      final jpegBytes = await compute(
        encodeRawPixelsAsJpeg,
        RawPixelsJpegRequest(data.buffer.asUint8List(), width, height),
      );
      if (jpegBytes.isEmpty) {
        return const MediaConversionResult.unsupported('encode-failed');
      }
      return MediaConversionResult(
        file: DropZoneFile(
          bytes: jpegBytes,
          name: withJpegExtension(file.name),
          size: jpegBytes.lengthInBytes,
          mimeType: _jpegMimeType,
        ),
      );
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}

/// Re-encodes raw RGBA pixels as JPEG, off the UI thread.
///
/// Top-level so it can run inside a background isolate, where it only touches
/// the pure-Dart `image` package and the plain data it was sent.
@visibleForTesting
Uint8List encodeRawPixelsAsJpeg(RawPixelsJpegRequest request) {
  final picture = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: request.pixels.buffer,
    bytesOffset: request.pixels.offsetInBytes,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(picture, quality: _jpegQuality);
}

/// The plain pixel payload the background isolate re-encodes.
///
/// Holds only transferable data — a byte list and dimensions — so the encode
/// request can cross the isolate boundary without dragging in engine handles.
@immutable
class RawPixelsJpegRequest {
  /// Creates the encode request for a [width] by [height] RGBA image.
  const RawPixelsJpegRequest(this.pixels, this.width, this.height);

  /// The raw RGBA pixel bytes of the decoded image.
  final Uint8List pixels;

  /// The decoded image width in pixels.
  final int width;

  /// The decoded image height in pixels.
  final int height;
}

/// Replaces [name]'s extension with the JPEG extension.
///
/// An extension-less name gains one, so every converted file carries the
/// extension matching its new contents.
String withJpegExtension(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  return '$base.$_jpegExtension';
}
