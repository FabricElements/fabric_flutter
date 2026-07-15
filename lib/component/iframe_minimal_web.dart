import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../helper/log_color.dart';

/// Embeds remote or inline HTML content in a browser [HtmlElementView].
///
/// The widget registers a platform view factory for the current iframe markup so
/// Flutter web can host content that must remain outside the normal canvas-based
/// rendering pipeline.
class IframeMinimal extends StatelessWidget {
  /// Creates a web iframe wrapper.
  ///
  /// Exactly one of [src] or [rawHtml] must be supplied so the browser knows
  /// whether to load an external document or inline markup.
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

  /// The remote URL assigned to the iframe's `src` attribute.
  final String? src;

  /// Inline markup assigned to the iframe's `srcdoc` attribute.
  final String? rawHtml;

  /// Alternative text exposed to assistive technologies through the DOM element.
  final String alt;

  /// The iframe title announced by browsers and accessibility tools.
  final String title;

  /// Builds and registers the HTML iframe element for the current widget configuration.
  @override
  Widget build(BuildContext context) {
    final id = '#iframe-${(src ?? rawHtml).hashCode}';
    final iframeElement = web.HTMLIFrameElement();

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
