import 'dart:ui' if (dart.library.html) 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' if (dart.library.html) 'dart:html'
    show IFrameElement;

class IframeMinimal extends StatelessWidget {
  const IframeMinimal({
    Key? key,
    required this.src,
    this.title = 'Iframe',
    this.alt = 'Iframe',
  }) : super(key: key);
  final String? src;
  final String alt;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (src == null) return const SizedBox();
    final id = '#iframe-${src.hashCode}';
    final iframeElement = IFrameElement();
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
      // ignore: avoid_print
      print('Error IframeMinimal: $e');
    }

    return HtmlElementView(
      key: Key(src.hashCode.toString()),
      viewType: id,
    );
  }
}
