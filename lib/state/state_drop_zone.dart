import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../component/alert_data.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/drop_file_format.dart';
import '../helper/firebase_storage_helper.dart';

/// Represents the upload lifecycle for a dropped or selected media item.
enum MediaDataUploadStatus {
  /// The file has been added locally but has not started uploading yet.
  pending,

  /// The file is currently being uploaded.
  uploading,

  /// The file upload completed successfully.
  uploaded,

  /// The file upload failed.
  failed,
}

/// Stores metadata and payload bytes for a media file being uploaded.
///
/// The payload is kept as raw [bytes] rather than a base64 string so the file is
/// never re-encoded in memory, which avoids the ~33% overhead of base64 and lets
/// the upload path stream the bytes straight to Storage.
class MediaDataUpload {
  /// Creates a media upload model for a dropped or selected file.
  MediaDataUpload({
    required this.contentType,
    required this.bytes,
    required this.extension,
    required this.fileName,
    this.height,
    required this.size,
    this.width,
    this.status = MediaDataUploadStatus.pending,
    this.error,
    this.path,
  });

  /// Stores the MIME type associated with the file contents.
  String contentType;

  /// Stores the raw file contents.
  Uint8List bytes;

  /// Stores the resolved file extension.
  String extension;

  /// Stores the display name of the file.
  String fileName;

  /// Stores the image height when that metadata is available.
  int? height;

  /// Stores the size of the file in bytes.
  int size;

  /// Stores the image width when that metadata is available.
  int? width;

  /// Tracks the current upload status for the file.
  MediaDataUploadStatus status;

  /// Stores the latest upload error message, when one exists.
  String? error;

  /// Stores the uploaded storage path after a successful upload.
  String? path;
}

/// Manages drag-and-drop selection, local upload state, and file uploads.
///
/// This state tracks the accepted [formats], the files staged for upload, and
/// their per-file progress, and exposes helper actions for both drag-and-drop and
/// manual file picking. The picker's allowed extensions are derived from
/// [formats] through [extensionsForFormats] so a single declaration drives both
/// acceptance paths.
class StateDropZone extends ChangeNotifier {
  /// Creates a drop-zone state that accepts the given [formats].
  StateDropZone({required this.formats})
    : extensions = extensionsForFormats(formats);

  /// The file formats accepted by both drag-and-drop and the file picker.
  final List<DropFileFormat> formats;

  /// The file extensions passed to the picker, derived from [formats].
  final List<String> extensions;

  /// Whether this state has already been disposed.
  bool _disposed = false;

  /// Whether this state has been disposed and must no longer notify listeners.
  ///
  /// Drops and uploads finish asynchronously, so callbacks can resolve long
  /// after the widget that owns this state is gone. In-flight work checks this
  /// to bail out instead of mutating state or notifying dead listeners.
  bool get disposed => _disposed;

  /// Marks this state as disposed and drops any pending selection.
  ///
  /// In-flight uploads are not cancellable at the Storage level, but they stop
  /// mutating this state and stop notifying listeners once [disposed] is true.
  @override
  void dispose() {
    _disposed = true;
    _mediaList.clear();
    super.dispose();
  }

  /// Notifies listeners unless this state has already been disposed.
  ///
  /// Late asynchronous callbacks would otherwise throw for using a disposed
  /// [ChangeNotifier].
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// Tracks whether the drop zone is currently processing or uploading files.
  bool _isLoading = false;

  /// Tracks whether a draggable item is currently hovering over the drop zone.
  bool _isDragging = false;

  /// Stores the media items selected for upload.
  final List<MediaDataUpload> _mediaList = [];

  /// Triggers a manual UI refresh without exposing [notifyListeners] directly.
  void refresh() => notifyListeners();

  /// Returns whether the drop zone is currently busy.
  bool get loading => _isLoading;

  /// Updates the loading flag and notifies listeners when it changes.
  set loading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  /// Maximum number of files uploaded to Storage at the same time.
  ///
  /// Uploads run concurrently for speed, but the count is capped so a large
  /// selection cannot saturate the network or open an unbounded number of
  /// simultaneous connections.
  static const int uploadConcurrency = 4;

  /// Returns whether a drag operation is currently active over the drop zone.
  bool get dragging => _isDragging;

  /// Returns an immutable view of the selected media items.
  List<MediaDataUpload> get mediaList => List.unmodifiable(_mediaList);

  /// Updates the drag-hover state and notifies listeners when it changes.
  void updateDragging(bool dragging) {
    if (_isDragging == dragging) return;
    _isDragging = dragging;
    notifyListeners();
  }

  /// Adds [media] to [mediaList] when it is not already present.
  ///
  /// Returns whether the item was added. A file is considered a duplicate when
  /// its file name, size, content type, and raw bytes all match an existing item.
  /// The cheap scalar fields are compared first so the byte-by-byte [listEquals]
  /// comparison only runs for otherwise-identical entries. Listeners are notified
  /// only when a new item is added.
  @visibleForTesting
  bool addMediaIfNew(MediaDataUpload media) {
    if (_disposed) return false;
    final isDuplicate = _mediaList.any(
      (m) =>
          m.fileName == media.fileName &&
          m.size == media.size &&
          m.contentType == media.contentType &&
          listEquals(m.bytes, media.bytes),
    );
    if (isDuplicate) return false;
    _mediaList.add(media);
    notifyListeners();
    return true;
  }

  /// Processes files delivered by a drop event and stages the supported ones.
  ///
  /// This resets the drag state, marks the drop zone as loading, and appends each
  /// accepted file to [mediaList] through [handleDroppedFile]. Reading has already
  /// happened in the drop region, so this only classifies and filters the bytes.
  Future<void> onDroppedFiles(List<DropZoneFile> files) async {
    updateDragging(false);
    loading = true;
    try {
      for (final file in files) {
        handleDroppedFile(file);
      }
    } finally {
      if (!_disposed) loading = false;
    }
  }

  /// Classifies a single dropped [file] and stages it when it is supported.
  ///
  /// The content type is taken from the browser, falling back to sniffing the
  /// bytes and finally to a `text/csv` guess for comma-separated data. Files that
  /// do not match any accepted [formats] are ignored, and the resolved extension
  /// is appended to the name when the original name lacked one. Returns whether
  /// the file was staged.
  @visibleForTesting
  bool handleDroppedFile(DropZoneFile file) {
    if (_disposed) return false;
    var name = file.name;
    String? contentType =
        file.mimeType ?? lookupMimeType(name, headerBytes: file.bytes);
    final extensionFromName = name.contains('.')
        ? name.split('.').lastOrNull?.toLowerCase()
        : null;
    if (contentType == null && extensionFromName == 'csv') {
      contentType = 'text/csv';
    }
    if (contentType == null) {
      debugPrint('Could not determine MIME type for file: $name');
      return false;
    }
    final accepted = formats.any(
      (format) => format.matches(contentType: contentType, fileName: name),
    );
    if (!accepted) return false;
    String? extension = extensionFromName ?? extensionFromMime(contentType);
    extension ??= contentType.contains('/')
        ? contentType.split('/').lastOrNull
        : null;
    if (extensionFromName == null && extension != null) {
      name += '.$extension';
    }
    return addMediaIfNew(
      MediaDataUpload(
        bytes: file.bytes,
        fileName: name,
        extension: extension ?? '',
        contentType: contentType,
        size: file.size,
      ),
    );
  }

  /// Removes the media item at [index] and clears the loading flag.
  void removeMedia(int index) {
    _mediaList.removeAt(index);
    _isLoading = false;
    notifyListeners();
  }

  /// Removes all selected media items and clears the loading flag.
  void clearAll() {
    _mediaList.clear();
    _isLoading = false;
    notifyListeners();
  }

  /// Removes only the files whose upload status is [MediaDataUploadStatus.uploaded].
  void clearSuccessfullyUploaded() {
    _mediaList.removeWhere(
      (media) => media.status == MediaDataUploadStatus.uploaded,
    );
    notifyListeners();
  }

  /// Opens the file picker and adds the selected files to [mediaList].
  ///
  /// Duplicate files are ignored. If no files are selected, the loading state is
  /// reset and no items are added. Bytes are kept raw, so no base64 encoding is
  /// performed on the picked files.
  Future<void> pickFiles() async {
    loading = true;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      loading = false;
      return;
    }
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final name = file.name;
      final mime = lookupMimeType(name, headerBytes: bytes);
      final ext = name.contains('.') ? name.split('.').last : '';
      addMediaIfNew(
        MediaDataUpload(
          bytes: bytes,
          fileName: name,
          extension: ext,
          contentType: mime ?? 'application/octet-stream',
          size: file.size,
        ),
      );
    }
    if (!kIsWeb) await FilePicker.clearTemporaryFiles();
    loading = false;
  }

  /// Uploads all queued media files to Firebase Storage.
  ///
  /// The uploaded file paths are passed to [callback]. Successful uploads are
  /// removed afterward, and localized success or error alerts are shown in the
  /// provided [context]. Files are uploaded as raw bytes through
  /// [FirebaseStorageHelper.saveFileData], and the transfers run concurrently up
  /// to [uploadConcurrency] so a large selection cannot open an unbounded number
  /// of simultaneous Storage connections.
  Future<void> upload({
    required BuildContext context,
    required String path,
    required Function(List<MediaDataUpload> media) callback,
    required bool expiry,
  }) async {
    if (_disposed || loading || mediaList.isEmpty) return;
    final firebaseStorageHelper = FirebaseStorageHelper(context);
    final locales = AppLocalizations.of(context);
    loading = true;
    for (final m in _mediaList) {
      m.status = MediaDataUploadStatus.uploading;
    }
    refresh();

    final pending = List<MediaDataUpload>.from(_mediaList);
    var nextIndex = 0;

    /// Uploads pending files one at a time from the shared [pending] queue.
    Future<void> worker() async {
      while (true) {
        if (_disposed || nextIndex >= pending.length) return;
        final m = pending[nextIndex++];
        if (m.status != MediaDataUploadStatus.uploading) continue;
        try {
          debugPrint('Uploading ${m.fileName}...');
          final finalPath = await firebaseStorageHelper.saveFileData(
            bytes: m.bytes,
            contentType: m.contentType,
            fileName: m.fileName,
            path: path,
            autoId: true,
            expiry: expiry,
          );
          m.path = finalPath;
          m.status = MediaDataUploadStatus.uploaded;
        } catch (e) {
          m.status = MediaDataUploadStatus.failed;
          m.error = e.toString();
          alertData(
            context: context.mounted ? context : null,
            body: locales.get(e.toString()),
            type: AlertType.critical,
          );
        } finally {
          if (!_disposed) refresh();
        }
      }
    }

    final workerCount = pending.length < uploadConcurrency
        ? pending.length
        : uploadConcurrency;
    await Future.wait(List.generate(workerCount, (_) => worker()));

    /// Collect results in the original selection order rather than in
    /// completion order, so [callback] receives the same sequence as before.
    final uploadedPaths = pending
        .where((m) => m.status == MediaDataUploadStatus.uploaded)
        .toList();

    /// Keep the success state visible briefly before the list is emptied.
    await Future.delayed(const Duration(seconds: 1));

    /// Only the presentation updates are skipped once disposed. The files are
    /// already in storage at this point, so skipping [callback] too would leave
    /// them orphaned and lose the caller's record of them.
    if (!_disposed) {
      clearSuccessfullyUploaded();
      loading = false;
      if (mediaList.isEmpty) {
        alertData(
          context: context.mounted ? context : null,
          body: locales.get('label--upload-complete'),
          type: AlertType.success,
        );
      }
    }
    if (uploadedPaths.isNotEmpty) {
      await callback(uploadedPaths);
    }
  }
}
