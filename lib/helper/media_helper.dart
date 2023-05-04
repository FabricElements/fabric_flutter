import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../serialized/media_data.dart';

enum MediaOrigin {
  camera,
  gallery,
  files,
}

/// Image helper class
class MediaHelper {
  /// Get Image as [MediaData]
  /// [origin] either 'camera' or 'gallery'
  static Future<MediaData> getImage({
    required MediaOrigin origin,
    int? maxDimensions,
  }) async {
    Uint8List? fileData;
    String? extension;
    String? contentType;
    String fileName = 'unknown';
    try {
      switch (origin) {
        case MediaOrigin.gallery:
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (result == null || result.files.isEmpty) {
            throw 'alert--no-chosen-files';
          }
          final file = result.files.first;
          if (file.size < 10) throw ('alert--file-is-too-small');
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
            allowedExtensions: ['png', 'jpg', 'jpeg', 'gif'],
          );
          fileData = base64Decode(dataFromFiles.data);
          extension = dataFromFiles.extension;
          contentType = dataFromFiles.contentType;
          fileName = dataFromFiles.fileName;
      }
    } catch (error) {
      if (kDebugMode) print('Getting the image: $error');
      rethrow;
    }
    try {
      if (fileData != null && maxDimensions != null) {
        fileData = await resize(
          imageByes: fileData,
          imageType: extension?.toString(),
          maxWidth: maxDimensions,
          maxHeight: maxDimensions,
        );
      }
    } catch (error) {
      if (kDebugMode) print('Resizing the image: $error');
      rethrow;
    }
    final encodeData = base64Encode(fileData!);
    return MediaData(
      data: encodeData,
      extension: extension!,
      contentType: contentType!,
      fileName: fileName,
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
        return img.copyResize(
          src,
          height: height,
          width: width,
        );
      }

      late Uint8List encodedImage;
      switch (imageType) {
        case 'gif':
          if (needsResize) {
            encodedImage = imageByes;
            // img.Animation? gifAnimation = img.decodeGifAnimation(imageByes);
            // img.Animation copyGif = img.Animation();
            // for (var element in gifAnimation!.frames) {
            //   copyGif.addFrame(_resize(element));
            // }
            // encodedImage = img.encodeGifAnimation(copyGif, samplingFactor: 20)
            //     as Uint8List;
          } else {
            /// Return same image if don't need to resize
            /// Gif doesn't perform right on flutter
            encodedImage = imageByes;
          }
          break;
        case 'png':
          baseImage = resizeSrc(baseImage);
          encodedImage = img.encodePng(baseImage, level: 10);
          break;
        case 'jpeg':
        case 'jpg':
        default:
          baseImage = resizeSrc(baseImage);
          encodedImage = img.encodeJpg(baseImage, quality: 95);
          break;
      }
      return encodedImage;
    } catch (error) {
      if (kDebugMode) print(error);
      // Check for specific errors, if not just return error
      throw Exception('alert--issue-resizing-image');
    }
  }

  /// Basic file selection
  static Future<MediaData> getFile({
    List<String>? allowedExtensions,
  }) async {
    Uint8List? fileData;
    String? extension;
    String? contentType;
    String? fileName;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) throw 'alert--no-chosen-files';
    final file = result.files.first;
    if (file.size < 10) throw ('alert--file-is-too-small');
    fileData = file.bytes;
    extension = file.extension;
    fileName = file.name;
    contentType = lookupMimeType(fileName);
    final encodeData = base64Encode(fileData!);
    return MediaData(
      data: encodeData,
      extension: extension!,
      contentType: contentType!,
      fileName: fileName,
    );
  }
}
