import 'dart:ui' if (dart.library.html) 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart'
    if (dart.library.html) 'dart:html'
    show IFrameElement, document;

import '../helper/log_color.dart';

class IframeMinimal extends StatelessWidget {
  const IframeMinimal({
    super.key,
    this.src,
    this.rawHtml,
    this.title = 'Iframe',
    this.alt = 'Iframe',
  }) : assert(
         (src != null && rawHtml == null) || (src == null && rawHtml != null),
         'Either src or rawHtml must be provided, but not both.',
       );

  final String? src;
  final String? rawHtml;
  final String alt;
  final String title;

  @override
  Widget build(BuildContext context) {
    final id = '#iframe-${(src ?? rawHtml).hashCode}';
    final iframeElement = IFrameElement();

    if (rawHtml != null) {
      iframeElement.setAttribute('srcdoc', rawHtml!);
    } else if (src != null) {
      iframeElement.setAttribute('src', src!);
    }

    iframeElement
      ..setAttribute('allowtransparency', 'true')
      ..setAttribute('allowfullscreen', 'true')
      // disable autoplay
      ..setAttribute('allow', "autoplay 'none'; fullscreen")
      ..setAttribute('height', '100%')
      ..setAttribute('width', '100%')
      ..setAttribute('alt', alt)
      ..setAttribute(
        'style',
        'border: none; height: 100%; width: 100%; background-color: transparent; pointer-events: auto;',
      )
      // disable scrolling
      ..setAttribute('scrolling', 'auto')
      ..setAttribute('title', title);

    try {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        id,
        (int viewId) => iframeElement,
      );
    } catch (e) {
      debugPrint(LogColor.error('Error IframeMinimal web: $e'));
    }

    return HtmlElementView(
      key: Key((src ?? rawHtml).hashCode.toString()),
      viewType: id,
    );
  }
}
