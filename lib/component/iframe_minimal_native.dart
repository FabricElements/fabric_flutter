import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Embeds a remote document in a native [WebViewWidget].
///
/// This widget mirrors the web implementation so shared widget trees can
/// request iframe-style content on every platform. When [src] is `null`, it
/// renders an empty box instead of creating a controller-backed view.
class IframeMinimal extends StatefulWidget {
  /// Creates a native iframe wrapper.
  ///
  /// Provide [src] to load a remote page. [rawHtml] is accepted for API parity
  /// with the web implementation, but native platforms currently render only
  /// URL-based content.
  const IframeMinimal({
    super.key,
    this.src,
    this.rawHtml,
    this.title = 'Iframe',
    this.alt = 'Iframe',
  });

  /// The remote URL loaded into the embedded web view.
  final String? src;

  /// Raw HTML kept for API parity with the web implementation.
  final String? rawHtml;

  /// Alternative text describing the embedded content when accessibility tools use it.
  final String alt;

  /// A human-readable title for the embedded frame.
  final String title;

  /// Creates the mutable state that configures and renders the web view.
  @override
  State<IframeMinimal> createState() => _IframeMinimalState();
}

/// Owns the [WebViewController] used to render iframe content on native platforms.
class _IframeMinimalState extends State<IframeMinimal> {
  /// Controls loading, navigation, and JavaScript execution for the embedded page.
  WebViewController controller = WebViewController();

  /// Initializes the controller once so rebuilds do not reload the page unexpectedly.
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

  /// Builds the platform view or an empty placeholder when no source URL exists.
  @override
  Widget build(BuildContext context) {
    if (widget.src == null) return const SizedBox();
    final id = '#iframe-${widget.src.hashCode}';
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      constraints: const BoxConstraints(
        minHeight: 300,
        minWidth: double.maxFinite,
      ),
      width: double.maxFinite,
      height: double.maxFinite,
      child: WebViewWidget(controller: controller, key: Key(id)),
    );
  }
}
