import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import platform-specific libraries
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class IframeMinimal extends StatefulWidget {
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
  State<IframeMinimal> createState() => _IframeMinimalState();
}

class _IframeMinimalState extends State<IframeMinimal>
    with WidgetsBindingObserver {
  WebViewController controller = WebViewController();
  bool _injectedEarly = false;

  // JavaScript that disables autoplay, pauses existing media and blocks programmatic play
  static const String _disableAutoplayScript = '''
(function() {
  function disableAutoplay() {
    try {
      var media = document.querySelectorAll('audio[autoplay], video[autoplay]');
      media.forEach(function(m) {
        try { m.pause(); m.removeAttribute('autoplay'); } catch(e) {}
      });

      var originalPlay = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function() {
        try {
          if (this.dataset && this.dataset._userInitiated === '1') {
            return originalPlay.apply(this, arguments);
          }
        } catch(e) {}
        return Promise.resolve();
      };

      var markUserInitiated = function() {
        document.querySelectorAll('audio,video').forEach(function(m) {
          try { m.dataset._userInitiated = '1'; } catch(e) {}
        });
        ['click','touchstart','keydown'].forEach(function(ev) {
          document.removeEventListener(ev, markUserInitiated, true);
        });
      };

      ['click','touchstart','keydown'].forEach(function(ev) {
        document.addEventListener(ev, markUserInitiated, true, { passive: true });
      });
    } catch(e) {}
  }

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    disableAutoplay();
  } else {
    document.addEventListener('DOMContentLoaded', disableAutoplay);
  }
})();
''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add the observer
    if (widget.src != null) {
      // Platform-specific controller creation params
      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          // Allows playback within the webview frame
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{
            PlaybackMediaTypes.video, // Requires user action for video playback
            PlaybackMediaTypes.audio, // Requires user action for audio playback
          },
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading bar.
              // inject early when very early progress is reported (prevents iOS autoplay)
              if (!_injectedEarly && progress < 10) {
                try {
                  controller.runJavaScript(_disableAutoplayScript);
                } catch (e) {
                  debugPrint('Early inject failed: $e');
                }
                _injectedEarly = true;
              }
            },
            onPageStarted: (String url) {
              debugPrint('Page started loading: $url');
              if (!_injectedEarly) {
                try {
                  controller.runJavaScript(_disableAutoplayScript);
                } catch (e) {
                  debugPrint('Start inject failed: $e');
                }
                _injectedEarly = true;
              }
            },
            onPageFinished: (String url) {
              debugPrint('Page finished loading: $url');
              // Inject JavaScript to pause any running videos
              try {
                controller.runJavaScript(_disableAutoplayScript);
              } catch (e) {
                debugPrint('Finish inject failed: $e');
              }
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
      // Platform-specific configuration for Android
      if (controller.platform is AndroidWebViewController) {
        (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(
              true,
            ); // Explicitly requires user gesture
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove the observer
    // Call a method to stop the video before disposing
    _stopVideoPlayback();
    super.dispose();
  }

  // Method to stop video playback by loading a blank URL
  void _stopVideoPlayback() {
    controller.loadHtmlString(''); //
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // When the app is paused (goes to background), stop the video
      _stopVideoPlayback(); //
    }
  }

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
