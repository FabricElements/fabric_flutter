/// Collects reusable regular expressions shared across validation helpers.
///
/// Keeping these expressions in one place makes form validation consistent
/// across the package and avoids subtle differences between widgets.
class RegexHelper {
  /// Matches a conventional email address structure used by form validation.
  ///
  /// The pattern accepts quoted local parts and bracketed IPv4 host literals,
  /// but it still represents a pragmatic client-side check rather than full RFC
  /// validation.
  static final email = RegExp(
    r'^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\])|(([a-zA-Z\-\d]+\.)+[a-zA-Z]{2,}))$',
  );
  /// Matches international phone numbers that start with `+` and 8-15 digits.
  ///
  /// This intentionally favors normalized E.164-style input so stored values
  /// remain easy to compare and transmit.
  static final phone = RegExp(r'^\+\d{8,15}');
  /// Matches digit-only phone numbers with no leading `+` sign.
  ///
  /// This is useful when user interfaces split country codes from the local
  /// number but still want the same length constraints as [phone].
  static final phoneNoPlusSign = RegExp(r'^\d{8,15}');
  /// Matches basic `http` and `https` URLs.
  ///
  /// The expression is designed for lightweight validation in forms and helpers,
  /// not for exhaustive URL parsing, so unusual but technically valid URLs may
  /// still be rejected.
  static final url = RegExp(
    r'(http|https)(://)[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  );

  /// Matches passwords that satisfy the package's minimum strength policy.
  ///
  /// Accepted passwords must contain at least one uppercase letter, one
  /// lowercase letter, one digit, one special character, and have a minimum
  /// length of eight characters. This keeps client-side validation aligned with
  /// the expectations used elsewhere in the app.
  static final password = RegExp(
    r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,}$',
  );
}
