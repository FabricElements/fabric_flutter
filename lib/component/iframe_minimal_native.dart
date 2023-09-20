import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(src!));

    return WebViewWidget(
      controller: controller,
      key: Key(id),
    );
  }
}
