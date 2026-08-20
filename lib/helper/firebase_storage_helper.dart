import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../component/alert_data.dart';
import '../serialized/media_data.dart';
import 'app_localizations_delegate.dart';
import 'log_color.dart';
import 'media_helper.dart';

/// Uploads, stores, and deletes files in Firebase Storage for package flows.
///
/// This helper keeps storage concerns close to the media-picking and alerting
/// utilities already used by the package. It offers both low-level upload
/// helpers and higher-level methods that surface localized error feedback to the
/// user interface.
class FirebaseStorageHelper {
  /// Provides access to localization and alert helpers during upload flows.
  BuildContext context;

  /// Creates a storage helper bound to [context].
  FirebaseStorageHelper(this.context);

  /// Saves raw string [data] to Firebase Storage at [path].
  ///
  /// The helper can append a timestamp when [autoId] is `true` and mark the path
  /// with an `_expiry` suffix when [expiry] is requested. This makes it suitable
  /// for storing generated assets whose final path should reflect lifecycle or
  /// uniqueness requirements.
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

  /// Saves a base64-encoded [file] and returns the resulting storage path.
  ///
  /// This wraps [save] with [PutStringFormat.base64] so media selected by the
  /// package can be uploaded without first writing a temporary file. When
  /// provided, [fileName] is exposed through the content disposition metadata so
  /// downstream downloads can preserve a friendly name.
  Future<String> saveFile({
    required String file,
    required String contentType,
    required String path,
    String? fileName,
    bool autoId = false,
    bool expiry = false,
  }) async {
    final fileSaved = await save(
      data: file,
      path: path,
      autoId: autoId,
      format: PutStringFormat.base64,
      metadata: SettableMetadata(
        contentType: contentType,
        contentDisposition: fileName != null
            ? 'inline; filename="$fileName"'
            : null,
      ),
      expiry: expiry,
    );
    return fileSaved.ref.fullPath;
  }

  /// Surfaces a localized alert describing a failed media upload.
  ///
  /// Both upload flows reach this after awaiting the picker and the storage
  /// write, so [context] may already be unmounted; in that case the alert is
  /// skipped rather than presented against a defunct element.
  void _reportMediaError(Object error) {
    if (!context.mounted) return;
    final locales = AppLocalizations.of(context);
    final errorMessage = error.toString();
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

  /// Lets the user pick an image, uploads it, and passes the result to [callback].
  ///
  /// Images are obtained through [MediaHelper.getImage], optionally resized with
  /// [maxDimensions], and then stored under [path]. Failures trigger a localized
  /// alert instead of throwing so UI flows can remain straightforward.
  Future uploadImageMedia({
    required MediaOrigin origin,
    required Function(String, MediaData) callback,
    required String path,
    required int maxDimensions,
    bool autoId = false,
    bool expiry = false,
  }) async {
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
      _reportMediaError(error);
    }
  }

  /// Lets the user pick a file, uploads it, and passes the result to [callback].
  ///
  /// Only files matching [fileExtensions] are accepted. When [maxFileSize] is
  /// supplied, oversized files are rejected before upload, and upload or picker
  /// errors are surfaced through localized alerts.
  Future uploadMedia({
    required Function(String, MediaData) callback,
    required String path,
    required List<String> fileExtensions,
    bool autoId = false,
    bool expiry = false,

    /// Optional maximum file size in bytes
    int? maxFileSize,
  }) async {
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
      _reportMediaError(error);
    }
  }

  /// Deletes the Firebase Storage object stored at [filePath].
  ///
  /// Missing files are treated as a successful no-op because cleanup code often
  /// runs after partial failures or repeated retries. Other Firebase errors are
  /// logged and rethrown so callers can decide whether to recover or abort.
  static Future<void> delete(String filePath) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final ref = storageRef.child(filePath);
      await ref.delete();
      if (kDebugMode) debugPrint('File deleted: $filePath');
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
