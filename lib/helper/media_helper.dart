import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../serialized/media_data.dart';
import 'log_color.dart';

enum MediaOrigin { camera, gallery, files }

/// Image helper class
class MediaHelper {
  /// Get Image as [MediaData]
  /// [origin] either 'camera' or 'gallery'
  static Future<MediaData> getImage({
    required MediaOrigin origin,
    int? maxDimensions,

    /// Optional maximum file size in bytes
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
          final baseDecoded = img.decodeImage(fileData)!;
          fileData = img.encodeJpg(baseDecoded);
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

  /// Scale an image to specified dimensions, pass the [imagePath] to the function
  /// and specify the [maxHeight] and/or [maxWidth] and this function will automatically
  /// scale the down or up to the specified.
  /// [imageType] Make sure the specify the return image file type, either [jpeg], [png] or [gif].+
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
      img.Image baseImage = img.decodeImage(imageByes)!;
      int height = baseImage.height;
      int width = baseImage.width;
      // Workout the scaling options, height going first being that height
      // is very often the largest value
      bool needsResize = height > maxHeight || width > maxWidth;
      if (height > maxHeight || width > maxWidth) {
        if (height > maxHeight) {
          width = (width / (height / maxHeight)).round();
          height = maxHeight;
        }
        if (width > maxWidth) {
          height = (height / (width / maxWidth)).round();
          width = maxWidth;
        }
      }

      img.Image resizeSrc(img.Image src) {
        /// Return same data if doesn't require resize
        if (!needsResize) return src;
        return img.copyResize(src, height: height, width: width);
      }

      late Uint8List encodedImage;
      switch (imageType) {
        case 'png':
          try {
            baseImage = resizeSrc(baseImage);
          } catch (error) {
            debugPrint(LogColor.error('Resizing PNG: $error'));
          }
          encodedImage = img.encodePng(baseImage);
          break;
        case 'jpeg':
        case 'jpg':
        default:
          try {
            baseImage = resizeSrc(baseImage);
          } catch (error) {
            debugPrint(LogColor.error('Resizing $imageType: $error'));
          }
          encodedImage = img.encodeJpg(baseImage, quality: 95);
          break;
      }
      return encodedImage;
    } catch (error) {
      debugPrint(LogColor.error(error));
      // Check for specific errors, if not just return error
      throw 'alert--issue-resizing-image';
    }
  }

  /// Basic file selection
  static Future<MediaData> getFile({
    /// Optional allowed extensions
    List<String>? allowedExtensions,

    /// Optional maximum file size in bytes
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
    if (contentType.contains('video')) {
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
