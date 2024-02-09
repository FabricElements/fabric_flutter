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
        height: 40,
        width: 40,
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading',
        ),
      );
    }
    final firebaseStorageHelper = FirebaseStorageHelper(context);
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context);
    return Wrap(
      spacing: 16,
      children: [
        IconButton(
          tooltip: locales.get('label--upload-from-label',
              {'label': locales.get('label--gallery')}),
          color: theme.colorScheme.primary,
          icon: const Icon(Icons.image),
          onPressed: () async {
            loading = true;
            if (mounted) setState(() {});
            await Future.delayed(const Duration(milliseconds: 100));
            await firebaseStorageHelper.uploadImageMedia(
              origin: MediaOrigin.gallery,
              callback: widget.callback,
              path: widget.path,
              maxDimensions: widget.maxDimensions,
              autoId: widget.autoId,
            );
            loading = false;
            if (mounted) setState(() {});
          },
        ),
        IconButton(
          tooltip: locales.get('label--upload-from-label',
              {'label': locales.get('label--file')}),
          color: theme.colorScheme.primary,
          icon: const Icon(Icons.image_search),
          onPressed: () async {
            loading = true;
            if (mounted) setState(() {});
            await Future.delayed(const Duration(milliseconds: 100));
            await firebaseStorageHelper.uploadImageMedia(
              origin: MediaOrigin.files,
              callback: widget.callback,
              path: widget.path,
              maxDimensions: widget.maxDimensions,
              autoId: widget.autoId,
            );
            loading = false;
            if (mounted) setState(() {});
          },
        ),
        !kIsWeb
            ? IconButton(
                tooltip: locales.get('label--upload-from-label',
                    {'label': locales.get('label--camera')}),
                color: theme.colorScheme.primary,
                icon: const Icon(Icons.photo_camera),
                onPressed: () async {
                  loading = true;
                  if (mounted) setState(() {});
                  await Future.delayed(const Duration(milliseconds: 100));
                  await firebaseStorageHelper.uploadImageMedia(
                    origin: MediaOrigin.camera,
                    callback: widget.callback,
                    path: widget.path,
                    maxDimensions: widget.maxDimensions,
                    autoId: widget.autoId,
                  );
                  loading = false;
                  if (mounted) setState(() {});
                },
              )
            : const SizedBox(),
      ],
    );
  }
}
