import 'package:flutter/foundation.dart';

/// Describes a file type accepted by a drop zone and its file picker.
///
/// A single [DropFileFormat] pairs a MIME [mimeType] with the file [extensions]
/// that map to it, so one declaration drives both drag-and-drop acceptance and
/// the `file_picker` `allowedExtensions` list. This removes the need to maintain
/// two hand-synchronized lists (formats and extensions) that historically drifted
/// apart.
@immutable
class DropFileFormat {
  /// Creates a drop file format for [mimeType] with its accepted [extensions].
  ///
  /// [extensions] are lowercase, dot-less identifiers (for example `png`). The
  /// first entry is treated as the canonical extension for the format.
  const DropFileFormat({required this.mimeType, required this.extensions});

  /// The canonical MIME type for this format, such as `image/png`.
  final String mimeType;

  /// The file extensions that resolve to this format, lowercase and dot-less.
  ///
  /// Multiple entries let a single format cover interchangeable extensions, such
  /// as `jpg` and `jpeg` both mapping to `image/jpeg`.
  final List<String> extensions;

  /// Determines whether a dropped or picked file matches this format.
  ///
  /// Content type takes precedence: when [contentType] is provided and equals
  /// [mimeType] (case-insensitive) the file matches immediately. Otherwise the
  /// lowercase extension parsed from [fileName] is used as the fallback and must
  /// be one of [extensions]. Extension fallback matters because browsers do not
  /// always report a reliable MIME type for every dropped file.
  bool matches({String? contentType, required String fileName}) {
    if (contentType != null &&
        contentType.toLowerCase() == mimeType.toLowerCase()) {
      return true;
    }
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return false;
    final extension = fileName.substring(dot + 1).toLowerCase();
    return extensions.contains(extension);
  }
}

/// Catalog of the file formats supported by the package drop zones.
///
/// Grouping the individual [DropFileFormat] entries here keeps the preset lists
/// below readable and gives consumers a single reference for the exact MIME and
/// extension coverage of each type.
abstract final class DropFileFormats {
  /// PNG image format.
  static const DropFileFormat png = DropFileFormat(
    mimeType: 'image/png',
    extensions: ['png'],
  );

  /// JPEG image format covering both `jpg` and `jpeg` extensions.
  static const DropFileFormat jpeg = DropFileFormat(
    mimeType: 'image/jpeg',
    extensions: ['jpg', 'jpeg'],
  );

  /// GIF image format.
  static const DropFileFormat gif = DropFileFormat(
    mimeType: 'image/gif',
    extensions: ['gif'],
  );

  /// MP3 audio format.
  static const DropFileFormat mp3 = DropFileFormat(
    mimeType: 'audio/mpeg',
    extensions: ['mp3'],
  );

  /// MPEG audio format registered under the `mpeg` extension.
  ///
  /// It shares `audio/mpeg` with [mp3] but keeps a distinct extension so the
  /// picker offers both, mirroring the previous format catalog.
  static const DropFileFormat mpeg = DropFileFormat(
    mimeType: 'audio/mpeg',
    extensions: ['mpeg'],
  );

  /// OGG audio format.
  static const DropFileFormat ogg = DropFileFormat(
    mimeType: 'audio/ogg',
    extensions: ['ogg'],
  );

  /// WAV audio format.
  static const DropFileFormat wav = DropFileFormat(
    mimeType: 'audio/wav',
    extensions: ['wav'],
  );

  /// MP4 video format.
  static const DropFileFormat mp4 = DropFileFormat(
    mimeType: 'video/mp4',
    extensions: ['mp4'],
  );

  /// QuickTime video format.
  static const DropFileFormat mov = DropFileFormat(
    mimeType: 'video/quicktime',
    extensions: ['mov'],
  );

  /// Comma-separated values format used for contact imports.
  static const DropFileFormat csv = DropFileFormat(
    mimeType: 'text/csv',
    extensions: ['csv'],
  );

  /// Legacy Excel spreadsheet format.
  static const DropFileFormat xls = DropFileFormat(
    mimeType: 'application/vnd.ms-excel',
    extensions: ['xls'],
  );

  /// Modern Excel spreadsheet format.
  static const DropFileFormat xlsx = DropFileFormat(
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    extensions: ['xlsx'],
  );

  /// PDF document format.
  static const DropFileFormat pdf = DropFileFormat(
    mimeType: 'application/pdf',
    extensions: ['pdf'],
  );
}

/// General media formats accepted by the default drop zone.
///
/// Covers images, audio, video, spreadsheets, and PDF documents. This is the
/// broadest preset and the sensible default when a screen accepts any supported
/// upload.
const List<DropFileFormat> dropZoneFormatsGeneral = [
  DropFileFormats.png,
  DropFileFormats.jpeg,
  DropFileFormats.gif,
  DropFileFormats.mp3,
  DropFileFormats.mpeg,
  DropFileFormats.ogg,
  DropFileFormats.wav,
  DropFileFormats.mp4,
  DropFileFormats.mov,
  DropFileFormats.csv,
  DropFileFormats.xls,
  DropFileFormats.xlsx,
  DropFileFormats.pdf,
];

/// Formats accepted for message-template media uploads.
///
/// Matches [dropZoneFormatsGeneral] minus the Excel spreadsheet formats, since a
/// message template only imports a `csv` alongside its media.
const List<DropFileFormat> dropZoneFormatsMessageTemplate = [
  DropFileFormats.png,
  DropFileFormats.jpeg,
  DropFileFormats.gif,
  DropFileFormats.mp3,
  DropFileFormats.mpeg,
  DropFileFormats.ogg,
  DropFileFormats.wav,
  DropFileFormats.mp4,
  DropFileFormats.mov,
  DropFileFormats.csv,
  DropFileFormats.pdf,
];

/// Audio formats accepted for call-recording uploads.
const List<DropFileFormat> dropZoneFormatsCallRecording = [
  DropFileFormats.mp3,
  DropFileFormats.wav,
];

/// Spreadsheet and CSV formats accepted for contact-list imports.
const List<DropFileFormat> dropZoneFormatsContactList = [
  DropFileFormats.csv,
  DropFileFormats.xls,
  DropFileFormats.xlsx,
];

/// Returns the deduplicated file extensions covered by [formats].
///
/// The result feeds the `file_picker` `allowedExtensions` argument so the picker
/// and the drag-and-drop surface stay driven by the same source of truth. Order
/// follows first appearance across [formats] to keep the picker list stable.
List<String> extensionsForFormats(List<DropFileFormat> formats) {
  final seen = <String>{};
  final result = <String>[];
  for (final format in formats) {
    for (final extension in format.extensions) {
      if (seen.add(extension)) result.add(extension);
    }
  }
  return result;
}

/// Carries the raw bytes and metadata of a file delivered by a drop region.
///
/// A [DropZoneFile] is the platform-neutral payload the web drop region hands to
/// [StateDropZone]. It lives in the helper layer so state code can consume it
/// without importing UI widgets, and it keeps bytes raw so no base64 round-trip
/// is required before upload.
@immutable
class DropZoneFile {
  /// Creates a dropped file payload from its [bytes] and metadata.
  const DropZoneFile({
    required this.bytes,
    required this.name,
    required this.size,
    this.mimeType,
  });

  /// The raw file contents as reported by the browser.
  final Uint8List bytes;

  /// The file name, including its extension when the browser provides one.
  final String name;

  /// The file size in bytes as reported by the browser.
  final int size;

  /// The MIME type the browser attached to the file, when available.
  ///
  /// A `null` value means the browser did not classify the file, in which case
  /// the consuming state resolves the type from the bytes and file name.
  final String? mimeType;
}
