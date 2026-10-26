import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

/// Email-link storage backed by the browser's `localStorage` on web.
///
/// Opening the link reloads the page, so the address has to survive a full
/// document teardown. `localStorage` is the only store that does without a
/// server round trip, and it is already scoped to the origin that requested the
/// link.
///
/// Every access is best-effort. A browser can refuse storage (private mode,
/// blocked cookies) and can throw on quota, and neither is a reason to fail a
/// sign-in: reads degrade to `null`, which the UI already handles by asking for
/// the address again.
class EmailLinkStorage {
  /// Identifies the `localStorage` entry holding the pending address.
  ///
  /// Namespaced so a host app sharing the origin with other tools cannot collide
  /// with it.
  static const String _key = 'fabric_flutter.email_link';

  /// Returns the address the last sign-in link was sent to, or `null`.
  ///
  /// `null` means either that no link was requested in this browser or that the
  /// store is unavailable; both turn into a prompt for the address.
  static String? read() {
    try {
      return web.window.localStorage.getItem(_key);
    } catch (error) {
      debugPrint('EmailLinkStorage: unable to read local storage: $error');
      return null;
    }
  }

  /// Remembers [email] as the address the next sign-in link was sent to.
  static void write(String email) {
    try {
      web.window.localStorage.setItem(_key, email);
    } catch (error) {
      debugPrint('EmailLinkStorage: unable to write local storage: $error');
    }
  }

  /// Forgets the stored address.
  ///
  /// Called once a link has been consumed so a stale address cannot be offered
  /// to a later, unrelated sign-in.
  static void clear() {
    try {
      web.window.localStorage.removeItem(_key);
    } catch (error) {
      debugPrint('EmailLinkStorage: unable to clear local storage: $error');
    }
  }

  /// Returns the current browser location, including path and query.
  ///
  /// The action link redirects the browser back to the continue URL it was
  /// created with, so the page that reopens is the page the user started from —
  /// query string and all. Reading it here is what lets the flow finish on
  /// exactly that page.
  static String? currentLocation() => Uri.base.toString();

  /// Removes the Firebase link parameters from the address bar.
  ///
  /// Opening a link lands the browser on the continue URL with `oobCode` and
  /// `mode` appended by Firebase. Redirecting or reloading would drop the
  /// `oobCode` before it is consumed, so the page stays put and rewrites its own
  /// address instead: the host page keeps its path and its own query parameters
  /// and continues whatever flow it was in, and a refresh or bookmark cannot
  /// hand the single-use code to Firebase a second time.
  ///
  /// Uses `history.replaceState` so the cleaned URL does not add a history
  /// entry, leaving the user's back button pointing at wherever they came from.
  /// Best-effort, like the store itself.
  static void clearLinkFromLocation() {
    try {
      final current = Uri.base;
      final kept = <String>[];
      current.queryParametersAll.forEach((key, values) {
        if (key == 'oobCode' || key == 'mode' || key == 'apiKey') return;
        for (final value in values) {
          kept.add(
            '${Uri.encodeQueryComponent(key)}='
            '${Uri.encodeQueryComponent(value)}',
          );
        }
      });
      final cleaned = Uri(
        scheme: current.scheme,
        userInfo: current.userInfo,
        host: current.host,
        port: current.port,
        path: current.path,
        query: kept.isEmpty ? null : kept.join('&'),
      );
      web.window.history.replaceState(null, '', cleaned.toString());
    } catch (error) {
      debugPrint('EmailLinkStorage: unable to clean the current URL: $error');
    }
  }
}
