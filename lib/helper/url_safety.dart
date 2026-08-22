import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Validates externally supplied URLs before they reach a platform handler.
///
/// Widgets in this package render data they did not author — table cells, chart
/// links, and decoded JSON all arrive from a backend or from another user. Any
/// string in that data can reach `url_launcher`, and `url_launcher` happily
/// hands a `file:`, `data:`, or `javascript:` URL to the platform. On a
/// tampered or simply misconfigured client that turns a value in a document
/// into local file access or script execution.
///
/// The guard is a **scheme allow-list**. A denylist of known-bad schemes is only
/// correct until a platform adds another one, whereas an allow-list fails safe
/// against the scheme nobody thought of.
class UrlSafety {
  /// Lists the URL schemes that may be handed to a platform handler.
  ///
  /// Only `https` and `http` are permitted. `http` remains allowed because
  /// consumers still link to plain-HTTP hosts, but callers that control their
  /// data should prefer `https`; see [isSafe] for the exact test applied.
  static const Set<String> allowedSchemes = {'https', 'http'};

  /// Returns the parsed URL when [url] is safe to launch, or `null` otherwise.
  ///
  /// Rejects a value that does not parse, that carries no scheme, or whose
  /// scheme is outside [allowedSchemes]. Comparison is case-insensitive because
  /// `Uri.scheme` is normalized to lower case but the input may not be.
  ///
  /// Prefer this over `Uri.parse` at a call site: `Uri.parse` succeeds for
  /// `javascript:alert(1)` and for `file:///etc/passwd`, and a caller that only
  /// checks whether parsing worked has not validated anything.
  static Uri? safeUri(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (!allowedSchemes.contains(uri.scheme.toLowerCase())) return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }

  /// Reports whether [url] carries an allowed scheme and a host.
  ///
  /// Use it to decide whether to render a value as a tappable link at all, so
  /// the UI never offers an action that [launch] would refuse.
  static bool isSafe(String? url) => safeUri(url) != null;

  /// Launches [url] when it passes [safeUri] and reports whether it was opened.
  ///
  /// Returns `false` without touching the platform when the URL is rejected, so
  /// a caller can stay silent or surface its own message. The rejected value is
  /// logged only under [kDebugMode] because it originates from user or backend
  /// data and does not belong in a release log.
  static Future<bool> launch(
    String? url, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    final uri = safeUri(url);
    if (uri == null) {
      if (kDebugMode) {
        debugPrint('UrlSafety.launch: rejected an unsupported URL scheme');
      }
      return false;
    }
    return launchUrl(uri, mode: mode);
  }
}
