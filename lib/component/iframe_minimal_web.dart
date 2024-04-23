import 'dart:ui' if (dart.library.html) 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' if (dart.library.html) 'dart:html'
    show IFrameElement;

import '../helper/log_color.dart';

class IframeMinimal extends StatelessWidget {
  const IframeMinimal({
    super.key,
    required this.src,
    this.title = 'Iframe',
    this.alt = 'Iframe',
  });

  final String? src;
  final String alt;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (src == null) return const SizedBox();
    final id = '#iframe-${src.hashCode}';
    final iframeElement = IFrameElement();
    // TODO: verify if everything can be added to allow and add it as custom attributes if can be implemented
    iframeElement.attributes = {
      'src': src!,
      'allowtransparency': 'true',
      'allowfullscreen': 'true',
      'allow': 'fullscreen',
      'height': '100%',
      'width': '100%',
      'alt': alt,
      'style':
          'border: none; height: 100%; width: 100%; background-color: transparent;',
      'title': title,
    };
    try {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        id,
        (int viewId) => iframeElement,
      );
    } catch (e) {
      debugPrint(LogColor.error('Error IframeMinimal: $e'));
    }

    return HtmlElementView(
      key: Key(src.hashCode.toString()),
      viewType: id,
    );
  }
}
