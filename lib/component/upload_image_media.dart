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
  });

  final Function(String, MediaData) callback;
  final String path;
  final int maxDimensions;
  final bool autoId;

  @override
  State<UploadImageMedia> createState() => _UploadImageMediaState();
}

class _UploadImageMediaState extends State<UploadImageMedia> {
  late bool loading;

  @override
  void initState() {
    loading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(semanticsLabel: 'Loading'),
      );
    }
    final firebaseStorageHelper = FirebaseStorageHelper(context);
    final locales = AppLocalizations.of(context);
    final uploadFromFile = ActionChip(
      label: Text(
        locales.get('label--upload-image-from-label', {
          'label': locales.get('label--file'),
        }),
      ),
      avatar: const Icon(Icons.image_search),
      onPressed: () async {
        loading = true;
        if (mounted) setState(() {});
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          await Future.microtask(
            () => firebaseStorageHelper.uploadImageMedia(
              origin: MediaOrigin.files,
              callback: widget.callback,
              path: widget.path,
              maxDimensions: widget.maxDimensions,
              autoId: widget.autoId,
            ),
          );
        } finally {
          loading = false;
          if (mounted) setState(() {});
        }
      },
    );
    if (kIsWeb) return uploadFromFile;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        ActionChip(
          label: Text(
            locales.get('label--upload-image-from-label', {
              'label': locales.get('label--gallery'),
            }),
          ),
          avatar: const Icon(Icons.image),
          onPressed: () async {
            loading = true;
            if (mounted) setState(() {});
            await Future.delayed(const Duration(milliseconds: 300));
            try {
              await Future.microtask(
                () => firebaseStorageHelper.uploadImageMedia(
                  origin: MediaOrigin.gallery,
                  callback: widget.callback,
                  path: widget.path,
                  maxDimensions: widget.maxDimensions,
                  autoId: widget.autoId,
                ),
              );
            } finally {
              loading = false;
              if (mounted) setState(() {});
            }
          },
        ),
        uploadFromFile,
        ActionChip(
          label: Text(
            locales.get('label--upload-image-from-label', {
              'label': locales.get('label--camera'),
            }),
          ),
          avatar: const Icon(Icons.photo_camera),
          onPressed: () async {
            loading = true;
            if (mounted) setState(() {});
            await Future.delayed(const Duration(milliseconds: 300));
            try {
              await Future.microtask(
                () => firebaseStorageHelper.uploadImageMedia(
                  origin: MediaOrigin.camera,
                  callback: widget.callback,
                  path: widget.path,
                  maxDimensions: widget.maxDimensions,
                  autoId: widget.autoId,
                ),
              );
            } finally {
              loading = false;
              if (mounted) setState(() {});
            }
          },
        ),
      ],
    );
  }
}
