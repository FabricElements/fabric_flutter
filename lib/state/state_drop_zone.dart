import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../component/alert_data.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/drop_file_format.dart';
import '../helper/firebase_storage_helper.dart';
import '../helper/media_file_converter.dart';

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
  ///
  /// The [converter] re-encodes files whose containers are accepted by the
  /// platform gallery but rejected downstream — most notably HEIC/HEIF photos —
  /// before they are staged, so only upload-safe bytes reach [mediaList]. It
  /// defaults to the platform converter and only needs to be provided in tests.
  StateDropZone({
    required this.formats,
    this.converter = const MediaFileConverterImpl(),
    this.conversionTimeout = mediaConversionTimeout,
  }) : extensions = extensionsForFormats(formats);

  /// The file formats accepted by both drag-and-drop and the file picker.
  final List<DropFileFormat> formats;

  /// Re-encodes containers that downstream storage rejects before staging.
  final MediaFileConverter converter;

  /// The longest a single [converter] call may take before the original file
  /// is staged unchanged instead.
  ///
  /// This bounds the whole drop even when a converter never settles. It is
  /// injectable so tests can exercise the deadline without waiting.
  final Duration conversionTimeout;

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

  /// Tracks whether a file conversion is currently running.
  bool _isConverting = false;

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

  /// Returns whether a file conversion is currently running.
  ///
  /// The drop zone stays interactive while a conversion runs — the heavy work
  /// happens off the UI thread — so the UI uses this flag to render a
  /// non-blocking progress affordance instead of freezing.
  bool get converting => _isConverting;

  /// Updates the converting flag and notifies listeners when it changes.
  set converting(bool value) {
    if (_isConverting == value) return;
    _isConverting = value;
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

  /// Returns the first accepted format matching [fileName] by extension alone.
  ///
  /// Used when a dropped file carries no MIME type and its bytes cannot be
  /// sniffed, mirroring the extension fallback in [DropFileFormat.matches] so
  /// the same files are accepted either way. Returns `null` when no accepted
  /// format covers the file's extension.
  DropFileFormat? _matchFormatByFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    final extension = fileName.substring(dot + 1).toLowerCase();
    for (final format in formats) {
      if (format.extensions.contains(extension)) return format;
    }
    return null;
  }

  /// Returns the accepted format matching [contentType] or [fileName].
  DropFileFormat? _matchFormat(String? contentType, String fileName) {
    for (final format in formats) {
      if (format.matches(contentType: contentType, fileName: fileName)) {
        return format;
      }
    }
    return null;
  }

  /// Files rejected since the last [clearRejections], newest last.
  final List<DropRejection> _rejections = [];

  /// Returns an immutable view of the files rejected by drops and picks.
  List<DropRejection> get rejections => List.unmodifiable(_rejections);

  /// Forgets the recorded [rejections].
  void clearRejections() => _rejections.clear();

  /// Records that [fileName] was not staged and warns the user.
  ///
  /// The warning is a localized alert naming the file and the reason, never a
  /// raw error string. Without a usable context the rejection is still recorded
  /// and only reaches the debug log, with the file name left out so nothing
  /// user-identifying is logged.
  void reportRejection(String fileName, DropRejectionReason reason) {
    if (_disposed) return;
    _rejections.add(DropRejection(fileName: fileName, reason: reason));
    final context = alertContext(null);
    if (context == null || !context.mounted) {
      debugPrint('[StateDropZone] file rejected (${reason.name})');
      return;
    }
    final locales = AppLocalizations.of(context);
    final String body;
    if (reason == DropRejectionReason.unreadable && fileName.isEmpty) {
      body = locales.get('label--drop-nothing-readable');
    } else {
      body = locales.get('label--drop-file-rejected', {
        'file': fileName,
        'reason': locales.get(_reasonKey(reason)),
      });
    }
    alertData(context: context, body: body, type: AlertType.warning);
  }

  /// Returns the localization key describing [reason].
  static String _reasonKey(DropRejectionReason reason) {
    switch (reason) {
      case DropRejectionReason.unsupportedType:
        return 'label--drop-reason-unsupported';
      case DropRejectionReason.unreadable:
        return 'label--drop-reason-unreadable';
      case DropRejectionReason.empty:
        return 'label--drop-reason-empty';
      case DropRejectionReason.conversionFailed:
        return 'label--drop-reason-conversion';
      case DropRejectionReason.duplicate:
        return 'label--drop-reason-duplicate';
    }
  }

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
  /// This resets the drag state, marks the drop zone as loading, and appends
  /// each accepted file to [mediaList] through [_convertAndStage]. Reading has
  /// already happened in the drop region, so this only converts, classifies,
  /// and filters the bytes.
  Future<void> onDroppedFiles(List<DropZoneFile> files) async {
    updateDragging(false);
    if (files.isEmpty) {
      reportRejection('', DropRejectionReason.unreadable);
      return;
    }
    loading = true;
    try {
      // Files convert one at a time so one heavy conversion cannot starve
      // the zone or interleave rejections out of order.
      for (final file in files) {
        await _convertAndStage(file);
      }
    } finally {
      if (!_disposed) {
        converting = false;
        loading = false;
      }
    }
  }

  /// Converts [file] through [converter] and stages the result.
  ///
  /// Every drop and pick goes through this pipeline so both entry points stage
  /// exactly the same bytes. When the conversion is required but cannot be
  /// performed, the file is not staged and the user is told through a localized
  /// alert; without a usable context the failure only reaches the debug log.
  Future<void> _convertAndStage(DropZoneFile file) async {
    if (file.unreadable) {
      reportRejection(file.name, DropRejectionReason.unreadable);
      return;
    }
    if (file.bytes.isEmpty) {
      reportRejection(file.name, DropRejectionReason.empty);
      return;
    }
    MediaConversionResult result;
    converting = true;
    try {
      result = await converter.convert(file).timeout(conversionTimeout);
    } on TimeoutException {
      result = const MediaConversionResult.unsupported('conversion-timeout');
    } catch (error) {
      // The converter contract says it never throws, but a broken double or
      // an engine edge case must still resolve instead of surfacing an
      // unhandled exception.
      debugPrint('[StateDropZone._convertAndStage] conversion error: $error');
      result = const MediaConversionResult.unsupported('converter-error');
    } finally {
      if (!_disposed) converting = false;
    }
    final converted = result.file;
    if (converted != null) {
      handleDroppedFile(converted);
      return;
    }
    // The conversion failed, is unsupported on this platform, or timed out.
    // The original file is staged unchanged whenever the accepted formats
    // already allow its type, so a platform that cannot convert never blocks a
    // drop the zone would otherwise take. Only a file whose original type is
    // not accepted is rejected, and the user is told why.
    final originalType =
        file.mimeType ?? lookupMimeType(file.name, headerBytes: file.bytes);
    if (_matchFormat(originalType, file.name) != null) {
      // The reason is a short internal identifier; the file name is
      // deliberately left out so nothing user-identifying reaches the log.
      debugPrint(
        '[StateDropZone._convertAndStage] conversion skipped, staging the '
        'original (${result.reason})',
      );
      handleDroppedFile(file);
      return;
    }
    _rejections.add(
      DropRejection(
        fileName: file.name,
        reason: DropRejectionReason.conversionFailed,
      ),
    );
    final context = alertContext(null);
    if (context == null || !context.mounted) {
      debugPrint(
        '[StateDropZone._convertAndStage] conversion failed '
        '(${result.reason})',
      );
      return;
    }
    alertData(
      context: context,
      body: AppLocalizations.of(context).get('label--media-conversion-failed'),
      type: AlertType.critical,
    );
  }

  /// Classifies a single dropped [file] and stages it when it is supported.
  ///
  /// The content type is taken from the browser, falling back to sniffing the
  /// bytes. When neither yields a type, the accepted [formats] decide by file
  /// name alone and the first matching format lends its canonical MIME type, so
  /// files dropped without a reported content type are still staged when their
  /// extension is accepted. Files that match no accepted format are ignored, and
  /// the resolved extension is appended to the name when the original name
  /// lacked one. Returns whether the file was staged.
  @visibleForTesting
  bool handleDroppedFile(DropZoneFile file) {
    if (_disposed) return false;
    var name = file.name;
    String? contentType =
        file.mimeType ?? lookupMimeType(name, headerBytes: file.bytes);
    final extensionFromName = name.contains('.')
        ? name.split('.').lastOrNull?.toLowerCase()
        : null;
    if (contentType == null) {
      final matchedFormat = _matchFormatByFileName(name);
      if (matchedFormat == null) {
        reportRejection(file.name, DropRejectionReason.unsupportedType);
        return false;
      }
      contentType = matchedFormat.mimeType;
    }
    final matched = _matchFormat(contentType, name);
    if (matched == null) {
      reportRejection(file.name, DropRejectionReason.unsupportedType);
      return false;
    }
    // Browsers report aliases (`image/jpg`, `audio/x-wav`) or a generic
    // `application/octet-stream` for files the extension already identifies, so
    // the accepted format's canonical type is staged instead.
    contentType = matched.mimeType;
    String? extension = extensionFromName ?? extensionFromMime(contentType);
    extension ??= contentType.contains('/')
        ? contentType.split('/').lastOrNull
        : null;
    if (extensionFromName == null && extension != null) {
      name += '.$extension';
    }
    final added = addMediaIfNew(
      MediaDataUpload(
        bytes: file.bytes,
        fileName: name,
        extension: extension ?? '',
        contentType: contentType,
        size: file.size,
      ),
    );
    if (!added) reportRejection(name, DropRejectionReason.duplicate);
    return added;
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
  /// performed on the picked files. Picked files pass through the same
  /// conversion pipeline as dropped ones, so a picked file whose container needs
  /// re-encoding is staged in the converted form — or rejected with the same
  /// localized message when the platform cannot convert it.
  Future<void> pickFiles() async {
    loading = true;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (files.isEmpty) {
      loading = false;
      return;
    }
    for (final file in files) {
      final bytes = await file.readAsBytes();
      await _convertAndStage(
        DropZoneFile(bytes: bytes, name: file.name, size: bytes.lengthInBytes),
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
  /// Uploads every staged item to [path] and reports the results through
  /// [callback].
  ///
  /// [customMetadata] is attached to each stored object so a caller can tag a
  /// whole selection for server-side handling. It is optional and defaults to
  /// no metadata, which keeps existing uploads unchanged.
  Future<void> upload({
    required BuildContext context,
    required String path,
    required Function(List<MediaDataUpload> media) callback,
    required bool expiry,
    Map<String, String>? customMetadata,
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
            customMetadata: customMetadata,
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
