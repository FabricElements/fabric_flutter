import 'package:flutter/foundation.dart';

import '../helper/input_validation.dart';

/// Stores transient state for multi-step phone and email-link views.
///
/// Widgets typically listen to this notifier while the user moves through phone
/// entry, verification-code entry, and confirmation flows, or through the
/// passwordless email-link steps. Each setter calls [notifyListeners], so
/// updates propagate immediately to any form field, progress indicator, or
/// submit button that depends on the current auth step.
class StateViewAuth extends ChangeNotifier {
  /// Stores the phone number exactly as entered by the user.
  ///
  /// The value intentionally excludes extra normalization so UI code can decide
  /// when to validate or reformat it.
  String? _phone;

  /// Returns the raw phone number entered by the user.
  String? get phone => _phone;

  /// Updates the raw phone number and notifies listeners.
  ///
  /// Reassigning the current value is ignored so per-keystroke controller
  /// listeners do not rebuild every dependent widget for a no-op change.
  set phone(String? value) {
    if (_phone == value) return;
    _phone = value;
    notifyListeners();
  }

  /// Stores the SMS verification code entered during sign-in.
  String? _phoneVerificationCode;

  /// Returns the current SMS verification code.
  String? get phoneVerificationCode => _phoneVerificationCode;

  /// Updates the SMS verification code and notifies listeners.
  set phoneVerificationCode(String? value) {
    if (_phoneVerificationCode == value) return;
    _phoneVerificationCode = value;
    notifyListeners();
  }

  /// Stores the Firebase verification identifier for the current auth attempt.
  String? _verificationId;

  /// Returns the Firebase verification identifier.
  String? get verificationId => _verificationId;

  /// Updates the Firebase verification identifier and notifies listeners.
  set verificationId(String? value) {
    if (_verificationId == value) return;
    _verificationId = value;
    notifyListeners();
  }

  /// Returns a minimally valid phone number candidate.
  ///
  /// Short or empty values resolve to `null` so submit actions can distinguish
  /// between incomplete input and a plausibly usable number.
  String? get phoneValid =>
      phone != null && phone!.isNotEmpty && phone!.length > 4 ? phone : null;

  /// Stores the current section or step index in the auth flow.
  int _section = 0;

  /// Returns the current section or step index.
  int get section => _section;

  /// Updates the current auth-flow section and notifies listeners.
  set section(int value) {
    if (_section == value) return;
    _section = value;
    notifyListeners();
  }

  /// Stores the email address entered for a passwordless sign-in link.
  String? _email;

  /// Returns the email address entered by the user.
  String? get email => _email;

  /// Updates the email address and notifies listeners.
  set email(String? value) {
    if (_email == value) return;
    _email = value;
    notifyListeners();
  }

  /// Returns the email address only when it is syntactically valid.
  ///
  /// Mirrors [phoneValid] so submit actions can gate on a plausibly usable
  /// address instead of a non-empty string.
  String? get emailValid => InputValidation.isEmailValid(email) ? email : null;

  /// Whether a sign-in link has been sent and the view is waiting on the inbox.
  bool _emailLinkSent = false;

  /// Returns whether the "check your inbox" step is active.
  bool get emailLinkSent => _emailLinkSent;

  /// Updates the "check your inbox" flag and notifies listeners.
  set emailLinkSent(bool value) {
    if (_emailLinkSent == value) return;
    _emailLinkSent = value;
    notifyListeners();
  }

  /// Whether the flow is waiting for the address before the link can complete.
  bool _awaitingEmailForLink = false;

  /// Returns whether the user must confirm the address the link was sent to.
  ///
  /// True when a link is being completed without a remembered address, which is
  /// what happens when the link is opened on a different device.
  bool get awaitingEmailForLink => _awaitingEmailForLink;

  /// Updates the missing-address flag and notifies listeners.
  set awaitingEmailForLink(bool value) {
    if (_awaitingEmailForLink == value) return;
    _awaitingEmailForLink = value;
    notifyListeners();
  }

  /// Stores the continue URL the sign-in link should return the user to.
  String? _returnUrl;

  /// Returns the continue URL captured when the link was requested.
  ///
  /// Held here so the flow can finish on the page the user started from, query
  /// string included, after the browser reloads.
  String? get returnUrl => _returnUrl;

  /// Updates the continue URL and notifies listeners.
  set returnUrl(String? value) {
    if (_returnUrl == value) return;
    _returnUrl = value;
    notifyListeners();
  }

  /// When the last sign-in link was sent, used to rate-limit resends.
  ///
  /// A timestamp rather than a counter so the cooldown survives a rebuild and
  /// cannot be bypassed by navigating away and back.
  DateTime? _lastEmailLinkSentAt;

  /// Returns when the last sign-in link was sent, or `null`.
  DateTime? get lastEmailLinkSentAt => _lastEmailLinkSentAt;

  /// Updates the last-send timestamp and notifies listeners.
  set lastEmailLinkSentAt(DateTime? value) {
    if (_lastEmailLinkSentAt == value) return;
    _lastEmailLinkSentAt = value;
    notifyListeners();
  }

  /// Resets all auth-view fields back to their initial state.
  ///
  /// Call this when leaving the flow or starting over so stale verification data
  /// does not leak into the next attempt.
  void clear() {
    _phone = null;
    _phoneVerificationCode = null;
    _verificationId = null;
    _email = null;
    _emailLinkSent = false;
    _awaitingEmailForLink = false;
    _returnUrl = null;
    _lastEmailLinkSentAt = null;
    _section = 0;
    notifyListeners();
  }
}
