import 'package:flutter/cupertino.dart';

/// [StateViewAuth]
///
/// This is a change notifier class which keeps track of state within the widgets.
class StateViewAuth extends ChangeNotifier {
  /// Phone number without country code 2233334
  String? _phone;

  String? get phone => _phone;

  set phone(String? value) {
    _phone = value;
    notifyListeners();
  }

  /// Phone verification code 123456
  int? _phoneVerificationCode;

  int? get phoneVerificationCode => _phoneVerificationCode;

  set phoneVerificationCode(int? value) {
    _phoneVerificationCode = value;
    notifyListeners();
  }

  /// Verification ID from Firebase
  String? _verificationId;

  String? get verificationId => _verificationId;

  set verificationId(String? value) {
    _verificationId = value;
    notifyListeners();
  }

  /// Complete phone number +12233334
  String? _phoneValid;

  /// Complete phone number +12233334
  String? get phoneValid => _phoneValid;

  /// Complete phone number +12233334
  set phoneValid(String? value) {
    _phoneValid = value;
    notifyListeners();
  }

  /// Section
  int _section = 0;

  /// Section
  int get section => _section;

  /// Section
  set section(int value) {
    _section = value;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _phone = null;
    _phoneValid = null;
    _phoneVerificationCode = null;
    _verificationId = null;
    _section = 0;
    notifyListeners();
  }
}
