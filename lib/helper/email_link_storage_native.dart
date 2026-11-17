/// In-memory email-link storage used on Android and iOS.
///
/// The app process survives the trip out to the mail client and back, so the
/// address only has to outlive a single page build. Keeping it in memory avoids
/// adding a key-value storage dependency and avoids leaving the user's address
/// on disk.
library;

import 'email_link_purpose.dart';

/// Remembers the email address a passwordless sign-in link was sent to.
///
/// The stored value is a single address, not a list: a new link replaces any
/// previous one, which mirrors Firebase's own single-pending-code behaviour.
class EmailLinkStorage {
  /// Holds the address the most recent sign-in link was sent to.
  static String? _email;

  /// Holds the purpose of the most recent stored link.
  static EmailLinkPurpose? _purpose;

  /// Returns the address the last sign-in link was sent to, or `null`.
  ///
  /// `null` means the link was requested on another device, which is the signal
  /// the UI turns into a prompt for the address.
  static String? read() => _email;

  /// Returns the purpose of the last stored link, or `null`.
  ///
  /// `null` means no purpose was recorded, which happens for entries written by
  /// an older version of this class. Callers treat an untagged entry as a
  /// sign-in link, preserving the behaviour of that older version.
  static EmailLinkPurpose? readPurpose() => _purpose;

  /// Remembers [email] as the address the next sign-in link was sent to.
  ///
  /// The [purpose] records which flow will redeem the link, so consumers that
  /// complete a different flow can leave the entry — and the single-use action
  /// code it pairs with — untouched.
  static void write(
    String email, {
    EmailLinkPurpose purpose = EmailLinkPurpose.signIn,
  }) {
    _email = email;
    _purpose = purpose;
  }

  /// Forgets the stored address.
  ///
  /// Called once a link has been consumed so a stale address cannot be offered
  /// to a later, unrelated sign-in.
  static void clear() {
    _email = null;
    _purpose = null;
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
