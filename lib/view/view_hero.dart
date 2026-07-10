import 'package:flutter/material.dart';

import '../component/smart_image.dart';

/// Displays a full-screen hero animation view for media content.
///
/// [ViewHero] creates an immersive, zoomable media viewing experience using
/// Flutter's Hero widget for smooth transitions. It's typically navigated to
/// from thumbnail images with matching hero tags. The view supports interactive
/// pinch-to-zoom and pan gestures through [InteractiveViewer].
///
/// The media URL is expected to be passed via route arguments with key 'url'.
/// If no URL is provided or the media fails to load, a fallback error message
/// is displayed.
class ViewHero extends StatelessWidget {
  /// Creates a hero animation view for media content.
  const ViewHero({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Map.from(
      ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>? ??
          {},
    );
    String? mediaUrl = args['url'];
    Widget content = const Padding(
      padding: EdgeInsets.all(16),
      child: Text('Your media file can\'t be loaded'),
    );
    if (mediaUrl != null) {
      content = SizedBox.expand(
        child: Hero(
          tag: 'hero-media',
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(16),
            child: SmartImage(
              key: ValueKey('hero-media-image-$mediaUrl'),
              url: mediaUrl,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(leading: const CloseButton()),
      body: content,
    );
  }
}
