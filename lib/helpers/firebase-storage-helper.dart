import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

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
    required this.reference,
  });

  final firebase_storage.Reference reference;

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
  Future<firebase_storage.TaskSnapshot> upload(File file, String path, String name,
      [String? contentType, Map<String, dynamic>? metadata]) async {
    final firebase_storage.Reference ref = reference.child(path).child(name);
    final firebase_storage.UploadTask uploadTask = ref.putFile(
      file,
      firebase_storage.SettableMetadata(
        contentType: contentType,
        customMetadata: metadata as Map<String, String>?,
      ),
    );
    firebase_storage.TaskSnapshot storageTaskSnapshot = await uploadTask.then((value) => value);
    return storageTaskSnapshot;
  }
}
