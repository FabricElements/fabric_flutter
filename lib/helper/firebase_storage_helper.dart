import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../component/alert_data.dart';
import '../serialized/media_data.dart';
import 'app_localizations_delegate.dart';
import 'log_color.dart';
import 'media_helper.dart';

/// This is a helper which uploads any type of file to the firebase storage path specified.
/// This helper returns the storage task snapshot for further use.
///
/// ```dart
/// FirebaseStorageHelper;
/// ```
class FirebaseStorageHelper {
  BuildContext context;

  FirebaseStorageHelper(this.context);

  /// This is a helper which uploads any type of file to the firebase storage path specified.
  /// This helper returns the storage task snapshot for further use.
  ///
  /// [file] The file to be uploaded.
  /// [path] The path within storage to put the file.
  /// [name] The name of the file.
  /// [contentType] The MIME content type of the file, if not specified firebase
  /// will detect from the extension, if no extension it will default to `application/octet-stream`.
  /// [metadata] Any additional metadata wanted to associate with the file, such as a user id, name or size.
  /// ```dart
  /// FirebaseStorageHelper(reference: FirebaseStorage.instance.ref()).upload(
  ///      file,
  ///      'path/to/folder',
  ///      'testFile.pdf',
  ///      'application/pdf',
  ///      {'name': 'testFile'},
  ///    );
  /// ```
  @Deprecated('use [FirebaseStorageHelper.save]')
  static Future<TaskSnapshot> upload(
    File file,
    String path,
    String name, [
    String? contentType,
    Map<String, dynamic>? metadata,
  ]) async {
    final storageRef = FirebaseStorage.instance.ref();
    final ref = storageRef.child(path).child(name);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: contentType,
        customMetadata: metadata as Map<String, String>?,
      ),
    );
    return await uploadTask.then((value) => value);
  }

  /// Save file
  /// Return file path with fileSavedReference.ref.fullPath
  static Future<TaskSnapshot> save({
    required String data,
    required String path,
    bool autoId = false,
    SettableMetadata? metadata,
    PutStringFormat format = PutStringFormat.raw,
    bool expiry = false,
  }) async {
    final storageRef = FirebaseStorage.instance.ref();
    String finalPath = path;
    if (autoId) {
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      finalPath += '_$time';
    }
    if (expiry) {
      finalPath += '_expiry';
    }
    final imagesRef = storageRef.child(finalPath);
    return imagesRef.putString(data, format: format, metadata: metadata);
  }

  /// Custom
  Future<String> saveFile({
    required String file,
    required String contentType,
    required String path,
    bool autoId = false,
    bool expiry = false,
  }) async {
    final fileSaved = await save(
      data: file,
      path: path,
      autoId: autoId,
      format: PutStringFormat.base64,
      metadata: SettableMetadata(contentType: contentType),
      expiry: expiry,
    );
    return fileSaved.ref.fullPath;
  }

  /// Upload image media
  Future uploadImageMedia({
    required MediaOrigin origin,
    required Function(String, MediaData) callback,
    required String path,
    required int maxDimensions,
    bool autoId = false,
    bool expiry = false,
  }) async {
    final locales = AppLocalizations.of(context);
    try {
      final selectedFile = await MediaHelper.getImage(
        origin: origin,
        maxDimensions: maxDimensions,
      );
      final finalPath = await saveFile(
        file: selectedFile.data,
        contentType: selectedFile.contentType,
        path: path,
        autoId: autoId,
        expiry: expiry,
      );
      return callback(finalPath, selectedFile);
    } catch (error) {
      String errorMessage = error.toString();
      final errorType = errorMessage == 'alert--no-chosen-files'
          ? AlertType.warning
          : AlertType.critical;
      alertData(
        context: context,
        body: locales.get(errorMessage),
        type: errorType,
        duration: 5,
      );
    }
  }

  Future uploadMedia({
    required Function(String, MediaData) callback,
    required String path,
    required List<String> fileExtensions,
    bool autoId = false,
    bool expiry = false,

    /// Optional maximum file size in bytes
    int? maxFileSize,
  }) async {
    final locales = AppLocalizations.of(context);
    try {
      final selectedFile = await MediaHelper.getFile(
        allowedExtensions: fileExtensions,
        maxFileSize: maxFileSize,
      );
      final finalPath = await saveFile(
        file: selectedFile.data,
        contentType: selectedFile.contentType,
        path: path,
        autoId: autoId,
        expiry: expiry,
      );
      return callback(finalPath, selectedFile);
    } catch (error) {
      String errorMessage = error.toString();
      final errorType = errorMessage == 'alert--no-chosen-files'
          ? AlertType.warning
          : AlertType.critical;
      alertData(
        context: context,
        body: locales.get(errorMessage),
        type: errorType,
        duration: 5,
      );
    }
  }

  /// Delete file safely
  static Future<void> delete(String filePath) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final ref = storageRef.child(filePath);
      await ref.delete();
      debugPrint('File deleted');
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        // File does not exist, treat as success
        debugPrint(
          LogColor.info('File at $filePath does not exist, nothing to delete.'),
        );
      } else {
        // Handle other possible errors (e.g., permission denied)
        debugPrint(
          LogColor.error('Failed to delete file at $filePath: ${e.message}'),
        );
        rethrow; // Re-throw if you want to handle it higher up
      }
    }
  }
}
