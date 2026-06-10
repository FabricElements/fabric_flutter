import 'app_localizations_delegate.dart';
import 'regex_helper.dart';

/// Validates common form values used throughout the app.
///
/// This helper centralizes the regular-expression checks and localized error
/// messages used by form fields so validation stays consistent across widgets
/// and custom input components.
class InputValidation {
  /// Creates an [InputValidation] helper that can return localized messages.
  const InputValidation({this.locales});

  /// Supplies localized fallback messages for validation failures.
  ///
  /// When [locales] is `null`, each validator falls back to a built-in English
  /// message so validation can still run outside a localized widget tree.
  final AppLocalizations? locales;

  /// Returns whether [password] satisfies the shared password requirements.
  ///
  /// Empty and `null` values are treated as invalid so callers can distinguish
  /// between missing input and a correctly formatted password before submitting
  /// data to an authentication backend.
  static bool isPasswordValid(String? password) {
    if (password == null || password.isEmpty) return false;
    return RegexHelper.password.hasMatch(password);
  }

  /// Returns whether [email] matches the app's accepted email pattern.
  ///
  /// Empty and `null` values return `false` because the helper is intended for
  /// form validation where blank values should fail unless explicitly optional.
  static bool isEmailValid(String? email) {
    if (email == null || email.isEmpty) return false;
    return RegexHelper.email.hasMatch(email);
  }

  /// Returns `null` when [email] is valid, or a localized error message.
  ///
  /// This method is designed for Flutter form validators, which treat `null`
  /// as success and any returned [String] as the message to display.
  String? validateEmail(String? email) {
    if (isEmailValid(email)) {
      return null;
    } else {
      return locales?.get('validation--email-address') ??
          'Enter a valid email address';
    }
  }

  /// Returns `null` when [password] is valid, or a localized error message.
  ///
  /// Using the same rules as [isPasswordValid] keeps UI feedback aligned with
  /// the password policy enforced elsewhere in the app.
  String? validatePassword(String? password) {
    if (isPasswordValid(password)) {
      return null;
    } else {
      return locales?.get('alert--invalid-password') ??
          'It must contain at least 8 characters, 1 uppercase, 1 lowercase, 1 symbol, and 1 number.';
    }
  }

  /// Returns `null` when [value] matches [regex], or an error message.
  ///
  /// This generic validator is useful for one-off checks that do not justify a
  /// dedicated helper method. When [message] is omitted, it falls back to a
  /// localized generic validation error.
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

  /// Returns whether [phone] matches the international phone-number pattern.
  ///
  /// This variant expects the canonical pattern defined in [RegexHelper.phone],
  /// which includes the leading plus sign when that is part of the format.
  static bool isPhoneValid(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    return RegexHelper.phone.hasMatch(phone);
  }

  /// Returns whether [phone] matches the phone-number pattern without `+`.
  ///
  /// This exists for input flows that store or display phone numbers without an
  /// international prefix marker while still reusing the shared regex rules.
  static bool isPhoneValidNoPlusSign(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    return RegexHelper.phoneNoPlusSign.hasMatch(phone);
  }

  /// Returns `null` when [phone] is valid, or a localized error message.
  ///
  /// The validator uses [isPhoneValidNoPlusSign] so it matches the formatting
  /// expected by the app's phone input fields.
  String? validatePhone(String? phone) {
    if (isPhoneValidNoPlusSign(phone)) {
      return null;
    } else {
      return locales?.get('validation--phone') ?? 'Enter a valid phone number';
    }
  }

  /// Returns whether [url] matches the shared URL pattern.
  ///
  /// Empty and `null` values are rejected because this helper is intended for
  /// required fields unless callers add their own optional-field handling.
  static bool isUrlValid(String? url) {
    if (url == null || url.isEmpty) return false;
    return RegexHelper.url.hasMatch(url);
  }

  /// Returns `null` when [url] is valid, or a localized error message.
  ///
  /// Keeping URL validation here avoids duplicating the same regex and fallback
  /// message in multiple forms.
  String? validateUrl(String? url) {
    if (isUrlValid(url)) {
      return null;
    } else {
      return locales?.get('validation--url') ?? 'Enter a valid URL';
    }
  }

  /// Returns whether [value] is not `null` and has a non-empty string value.
  ///
  /// Non-[String] values are converted with `toString()` so this helper can be
  /// reused by dropdowns, numeric inputs, and other form controls.
  static bool isNotEmpty(dynamic value) {
    if (value == null || value.toString().isEmpty) return false;
    return true;
  }

  /// Returns `null` when [value] is present, or a localized error message.
  ///
  /// This is the generic required-field validator used when a stricter format
  /// check is not necessary.
  String? validateNotEmpty(dynamic value) {
    if (isNotEmpty(value)) {
      return null;
    } else {
      return locales?.get('validation--not-empty') ??
          'This field can\'t be empty';
    }
  }
}
