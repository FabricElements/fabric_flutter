import 'app_localizations_delegate.dart';
import 'regex_helper.dart';

/// Use [InputValidation] for any form input or the custom InputData component
class InputValidation {
  const InputValidation({
    this.locales,
  });

  final AppLocalizations? locales;

  /// Returns true if contains a valid Email
  static bool isEmailValid(String? email) {
    if (email == null || email.isEmpty) return false;
    return RegexHelper.email.hasMatch(email);
  }

  /// Returns null if contains a valid Email
  String? validateEmail(String? email) {
    if (isEmailValid(email)) {
      return null;
    } else {
      return locales?.get('validation--email-address') ??
          'Enter a valid email address';
    }
  }

  /// Returns true if contains a valid phone number
  static bool isPhoneValid(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    return RegexHelper.phone.hasMatch(phone);
  }

  /// Returns null if contains a valid phone number
  String? validatePhone(String? phone) {
    if (isPhoneValid(phone)) {
      return null;
    } else {
      return locales?.get('validation--phone') ?? 'Enter a valid phone number';
    }
  }
}
