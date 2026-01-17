import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/firebase_storage_helper.dart';
import '../helper/media_helper.dart';
import '../serialized/media_data.dart';

class UploadImageMedia extends StatefulWidget {
  const UploadImageMedia({
    super.key,
    required this.callback,
    required this.path,
    this.maxDimensions = 1200,
    this.autoId = false,
    this.expiry = false,
  });

  final Function(String, MediaData) callback;
  final String path;
  final int maxDimensions;
  final bool autoId;
  final bool expiry;

  @override
  State<UploadImageMedia> createState() => _UploadImageMediaState();
}

class _UploadImageMediaState extends State<UploadImageMedia> {
  late bool loading;

  @override
  void initState() {
    super.initState();
    loading = false;
  }

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
