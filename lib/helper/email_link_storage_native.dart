/// In-memory email-link storage used on Android and iOS.
///
/// The app process survives the trip out to the mail client and back, so the
/// address only has to outlive a single page build. Keeping it in memory avoids
/// adding a key-value storage dependency and avoids leaving the user's address
/// on disk.
library;

/// Remembers the email address a passwordless sign-in link was sent to.
///
/// The stored value is a single address, not a list: a new link replaces any
/// previous one, which mirrors Firebase's own single-pending-code behaviour.
class EmailLinkStorage {
  /// Holds the address the most recent sign-in link was sent to.
  static String? _email;

  /// Returns the address the last sign-in link was sent to, or `null`.
  ///
  /// `null` means the link was requested on another device, which is the signal
  /// the UI turns into a prompt for the address.
  static String? read() => _email;

  /// Remembers [email] as the address the next sign-in link was sent to.
  static void write(String email) {
    _email = email;
  }

  /// Forgets the stored address.
  ///
  /// Called once a link has been consumed so a stale address cannot be offered
  /// to a later, unrelated sign-in.
  static void clear() {
    _email = null;
  }

  /// Returns the location the app is currently showing.
  ///
  /// Always `null` outside the web: there is no ambient URL to read, so the host
  /// app has to hand the incoming link to the flow itself.
  static String? currentLocation() => null;

  /// Removes the Firebase link parameters from the current location.
  ///
  /// A no-op outside the web, where the app owns its own navigation stack and no
  /// address bar can hold a leftover one-time code.
  static void clearLinkFromLocation() {}
}
