import 'package:fabric_flutter/helper/firebase_storage_helper.dart';
import 'package:fabric_flutter/helper/media_helper.dart';
import 'package:fabric_flutter/serialized/media_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UploadImageMedia extends StatefulWidget {
  const UploadImageMedia({
    Key? key,
    required this.callback,
    required this.path,
    this.maxDimensions = 1200,
  }) : super(key: key);
  final Function(String, MediaData) callback;
  final String path;
  final int maxDimensions;

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
    final firebaseStorageHelper = FirebaseStorageHelper(context);
    if (loading) {
      return const SizedBox(
        height: 40,
        width: 40,
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading',
        ),
      );
    }
    return Wrap(
      spacing: 16,
      children: [
        FloatingActionButton(
          mini: true,
          heroTag: 'upload-media-image',
          child: const Icon(Icons.image),
          onPressed: () async {
            loading = true;
            if (mounted) setState(() {});
            await Future.delayed(const Duration(milliseconds: 100));
            await firebaseStorageHelper.uploadImageMedia(
              origin: MediaOrigin.gallery,
              callback: widget.callback,
              path: widget.path,
              maxDimensions: widget.maxDimensions,
            );
            loading = false;
            if (mounted) setState(() {});
          },
        ),
        FloatingActionButton(
          mini: true,
          heroTag: 'upload-media-image-file',
          child: const Icon(Icons.upload_file),
          onPressed: () async {
            loading = true;
            if (mounted) setState(() {});
            await Future.delayed(const Duration(milliseconds: 100));
            await firebaseStorageHelper.uploadImageMedia(
              origin: MediaOrigin.files,
              callback: widget.callback,
              path: widget.path,
              maxDimensions: widget.maxDimensions,
            );
            loading = false;
            if (mounted) setState(() {});
          },
        ),
        !kIsWeb
            ? FloatingActionButton(
                mini: true,
                heroTag: 'upload-media-camera',
                child: const Icon(Icons.photo_camera),
                onPressed: () async {
                  loading = true;
                  if (mounted) setState(() {});
                  await Future.delayed(const Duration(milliseconds: 100));
                  await firebaseStorageHelper.uploadImageMedia(
                    origin: MediaOrigin.camera,
                    callback: widget.callback,
                    path: widget.path,
                    maxDimensions: widget.maxDimensions,
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
