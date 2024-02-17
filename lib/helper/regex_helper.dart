class RegexHelper {
  static final email = RegExp(
      r'^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\])|(([a-zA-Z\-\d]+\.)+[a-zA-Z]{2,}))$');
  static final phone = RegExp(r'^\+\d{8,15}');
  static final phoneNoPlusSign = RegExp(r'^\d{8,15}');
  static final url = RegExp(
      r'(http|https)(://)[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)');

  /// Password regex
  /// At least one upper case English letter, (?=.*?[A-Z])
  /// At least one lower case English letter, (?=.*?[a-z])
  /// At least one digit, (?=.*?[0-9])
  /// At least one special character, (?=.*?[#?!@$%^&*-])
  /// Minimum eight in length .{8,} (with the anchors)
  static final password =
      RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,}$');
}
