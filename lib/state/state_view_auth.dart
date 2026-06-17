import 'package:flutter/foundation.dart';

/// Stores transient state for multi-step phone-authentication views.
///
/// Widgets typically listen to this notifier while the user moves through phone
/// entry, verification-code entry, and confirmation flows. Each setter calls
/// [notifyListeners], so updates propagate immediately to any form field,
/// progress indicator, or submit button that depends on the current auth step.
class StateViewAuth extends ChangeNotifier {
  /// Stores the phone number exactly as entered by the user.
  ///
  /// The value intentionally excludes extra normalization so UI code can decide
  /// when to validate or reformat it.
  String? _phone;

  /// Returns the raw phone number entered by the user.
  String? get phone => _phone;

  /// Updates the raw phone number and notifies listeners.
  set phone(String? value) {
    _phone = value;
    notifyListeners();
  }

  /// Stores the SMS verification code entered during sign-in.
  String? _phoneVerificationCode;

  /// Returns the current SMS verification code.
  String? get phoneVerificationCode => _phoneVerificationCode;

  /// Updates the SMS verification code and notifies listeners.
  set phoneVerificationCode(String? value) {
    _phoneVerificationCode = value;
    notifyListeners();
  }

  /// Stores the Firebase verification identifier for the current auth attempt.
  String? _verificationId;

  /// Returns the Firebase verification identifier.
  String? get verificationId => _verificationId;

  /// Updates the Firebase verification identifier and notifies listeners.
  set verificationId(String? value) {
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
    _section = value;
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
    _section = 0;
    notifyListeners();
  }
}
