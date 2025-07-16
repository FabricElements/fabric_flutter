import 'app_localizations_delegate.dart';
import 'regex_helper.dart';

/// Use InputValidation for any form input or the custom InputData component
class InputValidation {
  const InputValidation({this.locales});

  final AppLocalizations? locales;

  /// Returns true if contains a valid Email
  static bool isPasswordValid(String? password) {
    if (password == null || password.isEmpty) return false;
    return RegexHelper.password.hasMatch(password);
  }

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

  /// Returns null if contains a valid password
  String? validatePassword(String? password) {
    if (isPasswordValid(password)) {
      return null;
    } else {
      return locales?.get('alert--invalid-password') ??
          'It must contain at least 8 characters, 1 uppercase, 1 lowercase, 1 symbol, and 1 number.';
    }
  }

  /// Validate RegEx match
  /// Returns null if contains a valid password or message if not
  String? validateMatch({
    required RegExp regex,
    required String? value,
    String? message,
  }) {
    final isValid = regex.hasMatch(value ?? '');
    if (isValid) {
      return null;
    } else {
      return message ?? locales?.get('alert--invalid-value') ?? 'Invalid value';
    }
  }

  /// Returns true if contains a valid phone number
  static bool isPhoneValid(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    return RegexHelper.phone.hasMatch(phone);
  }

  /// Returns true if contains a valid phone number
  static bool isPhoneValidNoPlusSign(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    return RegexHelper.phoneNoPlusSign.hasMatch(phone);
  }

  /// Returns null if contains a valid phone number
  String? validatePhone(String? phone) {
    if (isPhoneValidNoPlusSign(phone)) {
      return null;
    } else {
      return locales?.get('validation--phone') ?? 'Enter a valid phone number';
    }
  }

  /// Returns true if contains a valid url
  static bool isUrlValid(String? url) {
    if (url == null || url.isEmpty) return false;
    return RegexHelper.url.hasMatch(url);
  }

  /// Returns null if contains a valid url
  String? validateUrl(String? url) {
    if (isUrlValid(url)) {
      return null;
    } else {
      return locales?.get('validation--url') ?? 'Enter a valid URL';
    }
  }

  /// Returns true if contains a valid url
  static bool isNotEmpty(dynamic value) {
    if (value == null || value.toString().isEmpty) return false;
    return true;
  }

  /// Returns null if contains a valid url
  String? validateNotEmpty(dynamic value) {
    if (isNotEmpty(value)) {
      return null;
    } else {
      return locales?.get('validation--not-empty') ??
          'This field can\'t be empty';
    }
  }
}
