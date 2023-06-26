import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// import 'package:universal_html/html.dart' if (dart.library.html) 'dart:html'
//     show IFrameElement;
import 'package:universal_html/html.dart' show IFrameElement;

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
    final id = '#iframe-$src';
    final iframeElement = IFrameElement();
    // iframeElement.src = src;
    // iframeElement.style.border = 'none';
    // iframeElement.style.height = '100%';
    // iframeElement.style.width = '100%';
    // iframeElement.allowFullscreen = true;
    // iframeElement.height = '100%';
    // iframeElement.width = '100%';
    // iframeElement.style.backgroundColor = 'white';
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
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      id,
      (int viewId) => iframeElement,
    );
    return HtmlElementView(
      key: Key(src.hashCode.toString()),
      // key: UniqueKey(),
      viewType: id,
    );
  }
}
