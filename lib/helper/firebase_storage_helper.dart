library fabric_flutter;

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// This is a helper which uploads any type of file to the firebase storage path specified.
/// This helper returns the storage task snapshot for further use.
///
/// ```dart
/// FirebaseStorageHelper;
/// ```
class FirebaseStorageHelper {

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
  static Future<TaskSnapshot> upload(File file, String path, String name,
      [String? contentType, Map<String, dynamic>? metadata]) async {
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
  }) async {
    final storageRef = FirebaseStorage.instance.ref();
    String finalPath = path;
    if (autoId) {
      finalPath += '/${DateTime.now().millisecondsSinceEpoch.toString()}';
    }
    final imagesRef = storageRef.child(finalPath);
    return imagesRef.putString(data, format: format, metadata: metadata);
  }
}
