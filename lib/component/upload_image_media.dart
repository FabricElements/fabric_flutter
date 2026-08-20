import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
    final locales = AppLocalizations.of(context);

    if (loading) {
      return SizedBox(
        height: boxSize,
        width: boxSize,
        child: RefreshProgressIndicator(
          indicatorPadding: EdgeInsets.all(4.0),
          elevation: 1,
          semanticsLabel: locales.get('label--loading'),
        ),
      );
    }
    final theme = Theme.of(context);
    final firebaseStorageHelper = FirebaseStorageHelper(context);

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
            callback: (path, data) {
              widget.callback(path, data);
              // Upload failures are already surfaced through a visible,
              // screen-reader-announced alert inside FirebaseStorageHelper,
              // so only the success path needs an explicit announcement
              // here.
              if (mounted) {
                SemanticsService.sendAnnouncement(
                  View.of(context),
                  locales.get('notification--upload-success'),
                  Directionality.of(context),
                );
              }
            },
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
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => uploadFromOrigin(MediaOrigin.files),
      );
    }

    /// Mobile platform
    return PopupMenuButton<MediaOrigin>(
      padding: EdgeInsets.all(((48 - effectiveIconSize) / 2).clamp(0, 24)),
      iconSize: effectiveIconSize,
      icon: Icon(Icons.image_search, color: theme.colorScheme.primary),
      tooltip: locales.get('label--upload-label', {
        'label': locales.get('label--image'),
      }),
      itemBuilder: (context) => [
        for (final (origin, icon, labelKey) in const [
          (MediaOrigin.gallery, Icons.image, 'label--gallery'),
          (MediaOrigin.files, Icons.image_search, 'label--file'),
          (MediaOrigin.camera, Icons.photo_camera, 'label--camera'),
        ])
          PopupMenuItem(
            value: origin,
            child: Row(
              spacing: 16,
              children: [
                Icon(icon),
                Flexible(
                  child: Text(
                    locales.get('label--upload-image-from-label', {
                      'label': locales.get(labelKey),
                    }),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onSelected: uploadFromOrigin,
    );
  }
}
