import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Image helper class
class ImageHelper {
  /// Get fileurl
  /// [origin] either "camera" or "gallery"
  Future<String> getImage({required String origin, bool base64 = false}) async {
    late File baseImage;
    final picker = ImagePicker();
    if (origin == "camera") {
      PickedFile pickedFile = await (picker.pickImage(
          source: ImageSource.camera, maxWidth: 1500) as FutureOr<PickedFile>);
      baseImage = File(pickedFile.path);
    } else if (origin == "gallery") {
      FilePickerResult result = await (FilePicker.platform
          .pickFiles(type: FileType.image) as FutureOr<FilePickerResult>);
      baseImage = File(result.files.single.path!);
    }
    if (base64) {
      List<int> imageBytes = baseImage.readAsBytesSync();
      String base64Image = base64Encode(imageBytes);
      return base64Image;
    }
    return baseImage.path;
  }

  /// Scale an image to specified dimensions, pass the [imagePath] to the function
  /// and specify the [maxHeight] and/or [maxWidth] and this function will automatically
  /// scale the down or up to the specified.
  /// [imageType] Make sure the specify the return image file type, either [jpeg], [png] or [gif].+
  Future<String> resize({
    required String imagePath,
    required String imageType,
    double maxHeight = 1000,
    double maxWidth = 1000,
  }) async {
    try {
      String fileExt;
      switch (p.extension(imagePath).toLowerCase()) {
        case ".jpg":
        case ".jpeg":
        case ".jpe":
        case ".jif":
        case ".jfif":
        case ".jfi":
          fileExt = "jpeg";
          break;
        case ".png":
          fileExt = "png";
          break;
        case ".gif":
          fileExt = "gif";
          break;
        default:
          print("Invalid file type for image resize");
          throw Exception("Invalid file type for image resize");
      }
      Uint8List _imageByes = await File(imagePath).readAsBytes();
      img.Image _baseImage = img.decodeImage(_imageByes)!;
      double _height = _baseImage.height.toDouble();
      double _width = _baseImage.width.toDouble();
      // Workout the scaling options, height going first being that height is very often the largest value
      if (_height > maxHeight || _width > maxWidth) {
        if (_height > maxHeight) {
          _width = _width / (_height / maxHeight);
          _height = maxHeight;
        }
        if (_width > maxWidth) {
          _height = _height / (_width / maxWidth);
          _width = maxWidth;
        }
        _baseImage = img.copyResize(
          _baseImage,
          height: _height.round(),
          width: _width.round(),
        );
      }
      late Uint8List _encodedImage;
      switch (imageType) {
        case "jpeg":
          _encodedImage = img.encodeJpg(_baseImage) as Uint8List;
          break;
        case "png":
          _encodedImage = img.encodePng(_baseImage) as Uint8List;
          break;
        case "gif":
          _encodedImage = img.encodeGif(_baseImage) as Uint8List;
          break;
      }
      // Put the file in the cache and will expire in one minute
      File cachedImageFile = await DefaultCacheManager().putFile(
        "cachedImage",
        _encodedImage,
        maxAge: Duration(minutes: 1),
        fileExtension: fileExt,
        eTag: "cachedImage",
      );
      return cachedImageFile.path;
    } catch (error) {
      print(error);
      throw Exception(
          "There was an issue resizing the image."); // Check for specific errors, if not just return error
    }
  }
}
