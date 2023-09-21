import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class IframeMinimal extends StatefulWidget {
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
  State<IframeMinimal> createState() => _IframeMinimalState();
}

class _IframeMinimalState extends State<IframeMinimal> {
  WebViewController controller = WebViewController();

  @override
  void initState() {
    if (widget.src != null) {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading bar.
            },
            onPageStarted: (String url) {
              debugPrint('Page started loading: $url');
            },
            onPageFinished: (String url) {
              debugPrint('Page finished loading: $url');
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('Page error: $error');
            },
            onNavigationRequest: (NavigationRequest request) {
              // return NavigationDecision.prevent;
              // if (request.url.startsWith('https://www.youtube.com/')) {
              //   return NavigationDecision.prevent;
              // }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.src!));
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.src == null) return const SizedBox();
    final id = '#iframe-${widget.src.hashCode}';
    return Container(
      color: Colors.white,
      constraints: const BoxConstraints(
        minHeight: 300,
        minWidth: double.maxFinite,
      ),
      width: double.maxFinite,
      height: double.maxFinite,
      child: WebViewWidget(
        controller: controller,
        key: Key(id),
      ),
    );
  }
}
