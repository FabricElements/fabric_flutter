/// Native fallback for the media file converter.
///
/// The Flutter engine cannot decode HEIC/HEIF containers on Android, and on
/// iOS it only exposes platform APIs that the drop-zone pipeline does not call,
/// so there is no portable in-process conversion available for the raw bytes a
/// drop or a picker hands over. Reporting the conversion as unsupported lets
/// callers reject the file with a clear message instead of staging bytes that a
/// later upload step would refuse.
library;

import 'package:flutter/foundation.dart';

import 'drop_file_format.dart';

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
/// browser's image decoder, and this native implementation reports that the
/// conversion cannot be performed, because no portable decoder for the
/// affected containers is available in the engine. The public contract is
/// shared so callers write the same code on every platform.
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
  /// but cannot be performed — no decoder available, or the decode failed —
  /// the result carries [MediaConversionResult.reason] instead, and the caller
  /// must not stage the file.
  Future<MediaConversionResult> convert(DropZoneFile file);
}

/// The platform converter used where no in-process decoder is available.
///
/// Files that need no conversion pass through unchanged. A file whose
/// container requires a conversion is reported as unsupported rather than
/// staged as-is, because the raw bytes of those containers would otherwise
/// only fail later, at upload time, after the user has already moved on.
class MediaFileConverterImpl extends MediaFileConverter {
  /// Creates the native converter.
  const MediaFileConverterImpl();

  /// Passes [file] through, or reports it unsupported when it needs a
  /// conversion this platform cannot perform.
  @override
  Future<MediaConversionResult> convert(DropZoneFile file) async {
    if (!MediaFileConverter.needsConversion(
      mimeType: file.mimeType,
      fileName: file.name,
    )) {
      return MediaConversionResult(file: file);
    }
    return const MediaConversionResult.unsupported('conversion-unsupported');
  }
}
