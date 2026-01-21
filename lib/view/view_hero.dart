import 'package:flutter/material.dart';

import '../component/smart_image.dart';

class ViewHero extends StatelessWidget {
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
            child: SmartImage(url: mediaUrl),
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
