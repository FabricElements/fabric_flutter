import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';

/// This is a helper which uploads any type of file to the firebase storage path specified.
/// This helper returns the storage task snapshot for further use.
///
/// [reference] Application's firebase storage reference.
///
/// ```dart
/// FirebaseStorageHelper(reference: FirebaseStorage.instance.ref());
/// ```
class FirebaseStorageHelper {
  FirebaseStorageHelper({
    @required this.reference,
  });

  final StorageReference reference;

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
  ///      "path/to/folder",
  ///      "testFile.pdf",
  ///      "application/pdf",
  ///      {"name": "testFile"},
  ///    );
  /// ```
  Future<StorageTaskSnapshot> upload(File file, String path, String name,
      [String contentType, Map<String, dynamic> metadata]) async {
    final StorageReference ref = reference.child(path).child(name);
    final StorageUploadTask uploadTask = ref.putFile(
      file,
      StorageMetadata(
        contentType: contentType,
        customMetadata: metadata,
      ),
    );
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    return storageTaskSnapshot;
  }
}
