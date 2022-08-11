library fabric_flutter;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

enum MediaOrigin {
  camera,
  gallery,
  files,
}

class MediaObject {
  Uint8List data;
  String? contentType;
  String? extension;
  String? fileName;

  MediaObject({
    required this.data,
    this.contentType,
    this.extension,
    this.fileName,
  });
}

/// Image helper class
class MediaHelper {
  /// Get fileurl
  /// [origin] either 'camera' or 'gallery'
  static Future<MediaObject> getImage({
    required MediaOrigin origin,
    double? maxSize,
  }) async {
    Uint8List? fileData;
    String? extension;
    String? contentType;
    String? fileName;
    try {
      switch (origin) {
        case MediaOrigin.gallery:
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (result == null || result.files.isEmpty) {
            throw 'alert--no-choose-files';
          }
          final file = result.files.first;
          if (file.size < 1000) throw ('alert--file-is-too-small');
          fileData = file.bytes;
          extension = file.extension;
          fileName = file.name;
          contentType = lookupMimeType(file.name);
          break;
        case MediaOrigin.camera:
          if (kIsWeb) throw 'alert--not-implemented';
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
              source: ImageSource.camera, maxWidth: 1500);
          if (pickedFile == null) {
            throw 'alert--no-photo-was-taken';
          }
          File baseImage = File(pickedFile.path);
          fileData = baseImage.readAsBytesSync();
          final baseDecoded = img.decodeImage(fileData)!;
          fileData = img.encodeJpg(baseDecoded) as Uint8List;
          extension = 'jpeg';
          contentType = 'image/jpeg';
          break;
        case MediaOrigin.files:
          return await getFile(
            allowedExtensions: ['png', 'jpg', 'jpeg', 'gif'],
          );
      }
    } catch (error) {
      if (kDebugMode) print('Getting the image: $error');
      rethrow;
    }
    try {
      if (fileData != null && maxSize != null) {
        fileData = await resize(
          imageByes: fileData,
          imageType: extension?.toString(),
          maxWidth: maxSize,
          maxHeight: maxSize,
        );
      }
    } catch (error) {
      if (kDebugMode) print('Resizing the image: $error');
      rethrow;
    }

    if (fileData == null) throw 'alert--no-choose-files';

    return MediaObject(
      data: fileData,
      extension: extension,
      contentType: contentType,
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
    double maxHeight = 1000,
    double maxWidth = 1000,
  }) async {
    try {
      img.Image baseImage = img.decodeImage(imageByes)!;
      double height = baseImage.height.toDouble();
      double width = baseImage.width.toDouble();
      // Workout the scaling options, height going first being that height
      // is very often the largest value
      if (height > maxHeight || width > maxWidth) {
        if (height > maxHeight) {
          width = width / (height / maxHeight);
          height = maxHeight;
        }
        if (width > maxWidth) {
          height = height / (width / maxWidth);
          width = maxWidth;
        }
        baseImage = img.copyResize(
          baseImage,
          height: height.round(),
          width: width.round(),
        );
      }
      late Uint8List encodedImage;
      switch (imageType) {
        case 'png':
          encodedImage = img.encodePng(baseImage) as Uint8List;
          break;
        case 'gif':
          encodedImage = img.encodeGif(baseImage) as Uint8List;
          break;
        case 'jpeg':
        case 'jpg':
        default:
          encodedImage = img.encodeJpg(baseImage) as Uint8List;
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
  static Future<MediaObject> getFile({
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
    if (result == null || result.files.isEmpty) throw 'alert--no-choose-files';
    final file = result.files.first;
    if (file.size < 1000) throw ('alert--file-is-too-small');
    fileData = file.bytes;
    extension = file.extension;
    fileName = file.name;
    contentType = lookupMimeType(file.name);
    return MediaObject(
      data: fileData!,
      extension: extension,
      contentType: contentType,
      fileName: fileName,
    );
  }

  /// Save file
  static Future<String> save({
    required Uint8List data,
    required String path,
    bool autoId = false,
    SettableMetadata? metadata,
  }) async {
    final storageRef = FirebaseStorage.instance.ref();
    String finalPath = path;
    if (autoId) {
      finalPath += '/${DateTime.now().millisecondsSinceEpoch.toString()}';
    }
    final imagesRef = storageRef.child(finalPath);
    await imagesRef.putData(data, metadata);
    return finalPath;
  }
}
