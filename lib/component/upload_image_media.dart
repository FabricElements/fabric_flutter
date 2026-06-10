import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/firebase_storage_helper.dart';
import '../helper/media_helper.dart';
import '../serialized/media_data.dart';

/// Lets users pick an image from the supported platform sources and uploads it
/// through [FirebaseStorageHelper].
///
/// The widget keeps its own transient loading state so parent widgets can stay
/// simple while still reacting through [callback] once the upload completes.
class UploadImageMedia extends StatefulWidget {
  /// Creates an image upload trigger that delegates the final storage work to
  /// [FirebaseStorageHelper].
  const UploadImageMedia({
    super.key,
    required this.callback,
    required this.path,
    this.maxDimensions = 1200,
    this.autoId = false,
    this.expiry = false,
  });

  /// Receives the uploaded storage path together with the saved [MediaData].
  final Function(String, MediaData) callback;
  /// Defines the storage path prefix used for every uploaded image.
  final String path;
  /// Caps the largest image dimension before upload to reduce transfer costs.
  final int maxDimensions;
  /// Generates a storage identifier automatically when `true`.
  final bool autoId;
  /// Marks uploaded media as expiring when the storage layer supports it.
  final bool expiry;

  /// Creates the mutable state that tracks whether an upload is in progress.
  @override
  State<UploadImageMedia> createState() => _UploadImageMediaState();
}

/// Stores transient UI state for [UploadImageMedia] while the picker or upload
/// workflow is running.
class _UploadImageMediaState extends State<UploadImageMedia> {
  /// Prevents duplicate upload requests and swaps the trigger for progress UI.
  late bool loading;

  /// Initializes the state with no pending upload so the trigger is immediately
  /// interactive on first build.
  @override
  void initState() {
    super.initState();
    loading = false;
  }

  /// Builds either a compact progress indicator or the platform-specific image
  /// picker affordance.
  ///
  /// The upload callback is defined inside `build` so it always captures the
  /// latest widget configuration when Flutter rebuilds this state object.
  @override
  Widget build(BuildContext context) {
    final double effectiveIconSize = IconTheme.of(context).size ?? 24.0;
    final double boxSize = effectiveIconSize + 16;

    if (loading) {
      return SizedBox(
        height: boxSize,
        width: boxSize,
        child: RefreshProgressIndicator(
          indicatorPadding: EdgeInsets.all(4.0),
          elevation: 1,
          semanticsLabel: 'Loading',
        ),
      );
    }
    final theme = Theme.of(context);
    final firebaseStorageHelper = FirebaseStorageHelper(context);
    final locales = AppLocalizations.of(context);

    /// Upload function
    /// origin: MediaOrigin
    Future<void> uploadFromOrigin(origin) async {
      if (loading) return;
      loading = true;
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await Future.microtask(
          () => firebaseStorageHelper.uploadImageMedia(
            origin: origin,
            callback: widget.callback,
            path: widget.path,
            maxDimensions: widget.maxDimensions,
            autoId: widget.autoId,
            expiry: widget.expiry,
          ),
        );
      } finally {
        loading = false;
        if (mounted) setState(() {});
      }
    }

    /// Web platform
    if (kIsWeb) {
      return IconButton(
        tooltip: locales.get('label--upload-image-from-label', {
          'label': locales.get('label--file'),
        }),
        icon: const Icon(Icons.image_search),
        iconSize: effectiveIconSize,
        color: theme.colorScheme.primary,
        onPressed: () => uploadFromOrigin(MediaOrigin.files),
      );
    }

    /// Mobile platform
    return PopupMenuButton<MediaOrigin>(
      padding: EdgeInsets.zero,
      iconSize: effectiveIconSize,
      icon: Icon(Icons.image_search, color: theme.colorScheme.primary),
      tooltip: locales.get('label--upload-label', {
        'label': locales.get('label--image'),
      }),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: MediaOrigin.gallery,
          child: Row(
            spacing: 16,
            children: [
              const Icon(Icons.image),
              Text(
                locales.get('label--upload-image-from-label', {
                  'label': locales.get('label--gallery'),
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: MediaOrigin.files,
          child: Row(
            spacing: 16,
            children: [
              const Icon(Icons.image_search),
              Text(
                locales.get('label--upload-image-from-label', {
                  'label': locales.get('label--file'),
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: MediaOrigin.camera,
          child: Row(
            spacing: 16,
            children: [
              const Icon(Icons.photo_camera),
              Text(
                locales.get('label--upload-image-from-label', {
                  'label': locales.get('label--camera'),
                }),
              ),
            ],
          ),
        ),
      ],
      onSelected: uploadFromOrigin,
    );
  }
}
