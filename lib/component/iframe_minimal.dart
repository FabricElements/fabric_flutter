import 'dart:html';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class IframeMinimal extends StatelessWidget {
  const IframeMinimal({
    Key? key,
    required this.src,
    this.name = 'iframe',
  }) : super(key: key);
  final String? src;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (src == null) return const SizedBox();
    final id = '#iframe-$src';
    if (kIsWeb) {
      final IFrameElement iframeElement = IFrameElement();
      iframeElement.src = src;
      iframeElement.style.border = 'none';
      iframeElement.style.height = '100%';
      iframeElement.style.width = '100%';
      iframeElement.allowFullscreen = true;
      iframeElement.height = '100%';
      iframeElement.width = '100%';
      iframeElement.name = name;
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        id,
        (int viewId) => iframeElement,
      );
      return HtmlElementView(
        // key: Key(key),
        key: UniqueKey(),
        viewType: id,
      );
    }
    // ignore: undefined_prefixed_name
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(src!));

    return WebViewWidget(controller: controller);
  }
}
