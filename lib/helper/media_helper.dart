import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../serialized/media_data.dart';
import 'log_color.dart';

/// Decodes, optionally resizes, and re-encodes an image on a background isolate.
///
/// [args] carries the raw `bytes`, the target `imageType` (`jpeg` or `png`),
/// and the `maxHeight`/`maxWidth` bounds. Image decoding, resizing, and
/// encoding are CPU-bound and O(pixels), so running them on the UI isolate
/// stalled the frame pipeline for multi-megapixel photos.
///
/// Declared as a top-level function because `compute` can only invoke top-level
/// or static targets.
Uint8List _resizeImageWorker(Map<String, dynamic> args) {
  final Uint8List bytes = args['bytes'] as Uint8List;
  final String imageType = args['imageType'] as String;
  final int maxHeight = args['maxHeight'] as int;
  final int maxWidth = args['maxWidth'] as int;

  img.Image baseImage = img.decodeImage(bytes)!;
  int height = baseImage.height;
  int width = baseImage.width;
  // Workout the scaling options, height going first being that height
  // is very often the largest value
  final bool needsResize = height > maxHeight || width > maxWidth;
  if (needsResize) {
    if (height > maxHeight) {
      width = (width / (height / maxHeight)).round();
      height = maxHeight;
    }
    if (width > maxWidth) {
      height = (height / (width / maxWidth)).round();
      width = maxWidth;
    }
  }
  if (needsResize) {
    baseImage = img.copyResize(baseImage, height: height, width: width);
  }
  if (imageType == 'png') return img.encodePng(baseImage);
  return img.encodeJpg(baseImage, quality: 95);
}

/// Re-encodes camera bytes as JPEG on a background isolate.
///
/// Mirrors the decode/encode the camera branch previously performed inline on
/// the UI isolate.
Uint8List _encodeJpgWorker(Uint8List bytes) {
  return img.encodeJpg(img.decodeImage(bytes)!);
}

/// Runs [callback] off the UI isolate when the platform supports isolates.
///
/// Web builds have no isolate support, so the work is scheduled as a microtask
/// instead. If spawning the isolate fails for any reason the call falls back to
/// running inline so image handling never breaks outright. This mirrors the
/// pattern already used by `StateAPI` for streamed JSON parsing.
Future<R> _runOffThread<M, R>(ComputeCallback<M, R> callback, M message) async {
  if (kIsWeb) return Future.microtask(() => callback(message));
  try {
    return await compute(callback, message);
  } catch (error) {
    debugPrint(LogColor.error('Isolate unavailable, running inline: $error'));
    return callback(message);
  }
}

/// Identifies where media should be loaded from.
enum MediaOrigin {
  /// Captures a new image with the device camera.
  camera,

  /// Selects an existing image from the photo library.
  gallery,

  /// Selects a file through the platform file picker.
  files,
}

/// Loads and normalizes media selected by the user.
///
/// This helper wraps platform-specific picker behavior, common validation, and
/// metadata extraction so upload flows can work with a consistent [MediaData]
/// object regardless of where the file came from.
class MediaHelper {
  /// Returns an image selected from [origin] as [MediaData].
  ///
  /// The helper validates supported image extensions, optionally resizes large
  /// images, captures dimensions, and rejects files that exceed [maxFileSize].
  /// Camera capture is not supported on the web and throws accordingly.
  static Future<MediaData> getImage({
    required MediaOrigin origin,
    int? maxDimensions,

    /// Optional maximum file size in bytes.
    int? maxFileSize,
  }) async {
    Uint8List? fileData;
    String? extension;
    String? contentType;
    String fileName = 'unknown';
    int? width;
    int? height;
    final supportedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
    try {
      switch (origin) {
        case MediaOrigin.gallery:
          FilePickerResult? result = await FilePicker.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (result == null || result.files.isEmpty) {
            throw 'alert--no-chosen-files';
          }
          final file = result.files.first;
          if (file.size < 10) throw 'alert--file-is-too-small';
          fileData = file.bytes;
          extension = file.extension;
          fileName = file.name;
          contentType = lookupMimeType(file.name);
          break;
        case MediaOrigin.camera:
          if (kIsWeb) throw 'alert--not-implemented';
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: maxDimensions?.toDouble() ?? 1500,
            maxHeight: maxDimensions?.toDouble() ?? 1500,
          );
          if (pickedFile == null) {
            throw 'alert--no-photo-was-taken';
          }
          File baseImage = File(pickedFile.path);
          fileData = await baseImage.readAsBytes();
          fileData = await _runOffThread(_encodeJpgWorker, fileData);
          extension = 'jpeg';
          contentType = 'image/jpeg';
          break;
        case MediaOrigin.files:
          final dataFromFiles = await getFile(
            allowedExtensions: supportedExtensions,
          );
          fileData = base64Decode(dataFromFiles.data);
          extension = dataFromFiles.extension;
          contentType = dataFromFiles.contentType;
          fileName = dataFromFiles.fileName;
      }
    } catch (error) {
      debugPrint(LogColor.error('Getting the image: $error'));
      rethrow;
    } finally {
      if (!kIsWeb) await FilePicker.clearTemporaryFiles();
    }
    extension = extension?.toLowerCase();
    if (extension == null || !supportedExtensions.contains(extension)) {
      debugPrint(LogColor.error('Unsupported image format: $extension'));
      throw 'alert--unsupported-image-format';
    }
    try {
      if (fileData != null && maxDimensions != null) {
        fileData = await resize(
          imageByes: fileData,
          imageType: extension.toString(),
          maxWidth: maxDimensions,
          maxHeight: maxDimensions,
        );
      }
    } catch (error) {
      debugPrint(LogColor.warning('Resizing the image but continued: $error'));
    }
    try {
      if (fileData != null) {
        final decodedImage = await decodeImageFromList(fileData);
        width = decodedImage.width;
        height = decodedImage.height;
      }
    } catch (e) {
      debugPrint(LogColor.warning('Decoding image to get dimensions: $e'));
    }
    final fileSize = fileData?.lengthInBytes ?? 0;
    if (maxFileSize != null && fileData != null) {
      if (fileSize > maxFileSize) {
        throw 'label--warning-file-is-too-large';
      }
    }

    final encodeData = base64Encode(fileData!);
    return MediaData(
      data: encodeData,
      extension: extension,
      contentType: contentType!,
      fileName: fileName,
      width: width,
      height: height,
      size: fileSize,
    );
  }

  /// Resizes encoded image bytes to fit within the given bounds.
  ///
  /// The aspect ratio is preserved automatically. Only `jpeg`, `jpg`, and
  /// `png` are supported, and files already within the limits are returned with
  /// their original dimensions to avoid unnecessary processing.
  static Future<Uint8List> resize({
    required Uint8List imageByes,
    String? imageType,
    int maxHeight = 1000,
    int maxWidth = 1000,
  }) async {
    switch (imageType) {
      case 'jpeg':
      case 'jpg':
        imageType = 'jpeg';
        break;
      case 'png':
        imageType = 'png';
        break;
      default:
        throw 'alert--unsupported-image-format';
    }
    try {
      return await _runOffThread(_resizeImageWorker, <String, dynamic>{
        'bytes': imageByes,
        'imageType': imageType,
        'maxHeight': maxHeight,
        'maxWidth': maxWidth,
      });
    } catch (error) {
      debugPrint(LogColor.error(error));
      // Check for specific errors, if not just return error
      throw 'alert--issue-resizing-image';
    }
  }

  /// Returns a file selected with the system picker as [MediaData].
  ///
  /// The helper loads bytes into memory, records MIME information, and captures
  /// dimensions for images and videos when possible. Files larger than
  /// [maxFileSize] are rejected after selection.
  static Future<MediaData> getFile({
    /// Optional allowed extensions.
    List<String>? allowedExtensions,

    /// Optional maximum file size in bytes.
    int? maxFileSize,
  }) async {
    Uint8List? fileData;
    String? extension;
    String? contentType;
    String? fileName;
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) throw 'alert--no-chosen-files';
    final file = result.files.first;
    if (file.size == 0) throw 'alert--file-is-too-small';
    fileData = file.bytes!;
    extension = file.extension;
    fileName = file.name;
    int width = 0;
    int height = 0;
    contentType = lookupMimeType(fileName);
    final encodeData = base64Encode(fileData);
    // if image, get the width and height
    if (contentType!.contains('image')) {
      final decodedImage = await decodeImageFromList(fileData);
      width = decodedImage.width;
      height = decodedImage.height;
    }
    // wrap with try catch
    // if video, get width and height
    // `File.fromRawPath` comes from `dart:io` and throws `UnsupportedError` on
    // web, so video dimensions are only probed on native platforms.
    if (contentType.contains('video') && !kIsWeb) {
      // TODO: Verify this works
      try {
        // file from Uint8List
        final video = VideoPlayerController.file(File.fromRawPath(fileData));
        width = video.value.size.width.toInt();
        height = video.value.size.height.toInt();
        debugPrint(LogColor.info('width: $width, height: $height'));
      } catch (e) {
        debugPrint(LogColor.error(e));
      }
    }

    final fileSize = file.size;
    if (!kIsWeb) await FilePicker.clearTemporaryFiles();
    if (maxFileSize != null && fileSize > maxFileSize) {
      throw 'label--warning-file-is-too-large';
    }

    return MediaData(
      data: encodeData,
      extension: extension!,
      contentType: contentType,
      fileName: fileName,
      size: file.size,
      width: width,
      height: height,
    );
  }
}
