/// Collects every regular expression used across the package.
///
/// This class is the single source of truth for regular expressions in
/// `fabric_flutter`. Widgets, helpers, and state containers must reference
/// these constants instead of declaring their own literals so that:
///
/// * validation semantics stay identical everywhere,
/// * equivalent patterns are not silently duplicated, and
/// * every pattern is compiled exactly once at class-initialization time
///   rather than on each call, `build()`, or keystroke.
///
/// Patterns are grouped by concern. When adding a new expression, place it in
/// the matching section, give it a `///` comment describing what it matches,
/// what it does *not* match, and a concrete matching/non-matching example.
///
/// Every member is `static final RegExp`. Never declare a `RegExp` inside a
/// function, a `build()` method, or an item builder.
class RegexHelper {
  // ---------------------------------------------------------------------------
  // Identity and contact
  // ---------------------------------------------------------------------------

  /// Matches a conventional email address structure used by form validation.
  ///
  /// The pattern accepts quoted local parts and bracketed IPv4 host literals,
  /// but it still represents a pragmatic client-side check rather than full RFC
  /// validation.
  ///
  /// Does **not** match values without an `@`, without a dotted domain, or with
  /// whitespace in the local part.
  ///
  /// Matches: `user@example.com`. Does not match: `user@`.
  static final RegExp email = RegExp(
    r'^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\])|(([a-zA-Z\-\d]+\.)+[a-zA-Z]{2,}))$',
  );

  /// Matches international phone numbers that start with `+` and 8-15 digits.
  ///
  /// This intentionally favors normalized E.164-style input so stored values
  /// remain easy to compare and transmit.
  ///
  /// Does **not** match numbers without the leading `+`, or fewer than eight
  /// digits. The expression is unanchored at the end, so trailing characters
  /// after a valid prefix are tolerated.
  ///
  /// Matches: `+14155552671`. Does not match: `14155552671`.
  static final RegExp phone = RegExp(r'^\+\d{8,15}');

  /// Matches digit-only phone numbers with no leading `+` sign.
  ///
  /// This is useful when user interfaces split country codes from the local
  /// number but still want the same length constraints as [phone].
  ///
  /// Does **not** match numbers shorter than eight digits or values that start
  /// with `+`.
  ///
  /// Matches: `14155552671`. Does not match: `1234`.
  static final RegExp phoneNoPlusSign = RegExp(r'^\d{8,15}');

  /// Matches username identifiers used by forms and authentication.
  ///
  /// Allows only lowercase ASCII letters (a-z) and digits (0-9), with a length
  /// between 3 and 30 characters inclusive.
  ///
  /// Does **not** match uppercase letters, whitespace, underscores, dots, or
  /// any other punctuation.
  ///
  /// Matches: `user123`. Does not match: `User_Name`.
  static final RegExp username = RegExp(r'^[a-z0-9]{3,30}$');

  /// Matches passwords that satisfy the package's minimum strength policy.
  ///
  /// Accepted passwords must contain at least one uppercase letter, one
  /// lowercase letter, one digit, one special character from `#?!@$%^&*-`, and
  /// have a minimum length of eight characters.
  ///
  /// Does **not** match passwords that are shorter than eight characters or
  /// that are missing any one of the four required character classes.
  ///
  /// Matches: `Str0ng!Pass`. Does not match: `Str0ngPass`.
  static final RegExp password = RegExp(
    r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,}$',
  );

  /// Matches a canonical RFC 4122 UUID in its lowercase or uppercase hyphenated
  /// form.
  ///
  /// Does **not** match UUIDs without hyphens, braced Microsoft-style GUIDs, or
  /// URNs prefixed with `urn:uuid:`.
  ///
  /// Matches: `3f2504e0-4f89-11d3-9a0c-0305e82c3301`.
  /// Does not match: `3f2504e04f8911d39a0c0305e82c3301`.
  static final RegExp uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  // ---------------------------------------------------------------------------
  // Web, links, and media types
  // ---------------------------------------------------------------------------

  /// Matches a string that **contains** an `http` or `https` URL.
  ///
  /// > **Warning:** this pattern is deliberately **unanchored** and is kept
  /// > only for backwards compatibility. It reports a match for any string that
  /// > merely contains something URL-shaped, so it is **not** suitable as a
  /// > form validator. Use [urlStrict] to validate that a value *is* a URL, or
  /// > [urlInText] to pull links out of prose.
  ///
  /// Does **not** match scheme-less values, `mailto:` links, or other custom
  /// protocols.
  ///
  /// Matches: `https://example.com/path` — but also `garbage https://a.com`
  /// and `xhttps://example.com`. Does not match: `example.com`.
  static final RegExp url = RegExp(
    r'(http|https)(://)[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  );

  /// Matches a value that **is** an `http` or `https` URL, end to end.
  ///
  /// This is the anchored counterpart to [url] and the pattern that should be
  /// used for form validation. It accepts the same URL shapes as [url] but
  /// rejects anything with leading or trailing content.
  ///
  /// Does **not** match scheme-less values, other protocols such as `ftp://`,
  /// or a valid URL embedded in a larger string.
  ///
  /// Matches: `https://example.com/a?b=c#d`.
  /// Does not match: `garbage https://example.com`.
  static final RegExp urlStrict = RegExp(
    r'^https?://[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  /// Extracts `http` and `https` links from free-form text.
  ///
  /// Unlike [urlStrict], this is deliberately greedy up to the next whitespace
  /// character so it can pull links out of a sentence. It is an *extraction*
  /// pattern, not a validation pattern.
  ///
  /// Does **not** match scheme-less links, and it happily captures trailing
  /// punctuation — pair it with [trailingPunctuation] to clean the result.
  ///
  /// Matches `https://example.com/a,` inside `See https://example.com/a, now`.
  /// Does not match: `see example.com`.
  static final RegExp urlInText = RegExp(r'(https?://[^\s]+)');

  /// Matches a MIME content type and captures its top-level (primary) type.
  ///
  /// Capture group 1 is the type segment before the `/`, which makes it useful
  /// for branching on `image`, `video`, or `application` payloads.
  ///
  /// Does **not** match values without a `/` separator or with an empty
  /// subtype.
  ///
  /// Matches: `image/png` (group 1 is `image`). Does not match: `image`.
  static final RegExp mimePrimaryType = RegExp(r'([a-zA-Z0-9_-]+)/.+$');

  /// Matches a single HTML or XML tag, including closing and self-closing tags.
  ///
  /// Intended for stripping markup out of text with `replaceAll`, not for
  /// parsing HTML.
  ///
  /// Does **not** match tag *contents*, and it is not aware of `<` characters
  /// that appear inside attribute values.
  ///
  /// Matches: `<b>` and `</b>` in `<b>hi</b>`. Does not match: `a < b`.
  static final RegExp htmlTag = RegExp(r'<[^>]*>');

  // ---------------------------------------------------------------------------
  // Whitespace
  // ---------------------------------------------------------------------------

  /// Matches any run of whitespace, including spaces, tabs, and newlines.
  ///
  /// Use it with `replaceAll` to collapse or strip whitespace, or with `split`
  /// to tokenize a sentence.
  ///
  /// Does **not** match zero-width or other invisible formatting characters —
  /// use [formattingOnly] for those.
  ///
  /// Matches the gap in `a  \t b`. Does not match: `ab`.
  static final RegExp whitespace = RegExp(r'\s+');

  /// Matches a run of two or more literal space characters.
  ///
  /// This is narrower than [whitespace] because it deliberately preserves tabs
  /// and newlines while collapsing only horizontal spacing.
  ///
  /// Does **not** match tabs or newlines.
  ///
  /// Matches the gap in `a   b`. Does not match the newline in `a\nb`.
  static final RegExp multipleSpaces = RegExp(r' +');

  /// Matches three or more consecutive newline characters.
  ///
  /// Used to normalize an arbitrary number of blank lines down to a single
  /// blank line.
  ///
  /// Does **not** match one or two consecutive newlines.
  ///
  /// Matches `\n\n\n` in `a\n\n\nb`. Does not match `\n\n` in `a\n\nb`.
  static final RegExp extraNewlines = RegExp(r'\n{3,}');

  /// Matches Unicode formatting-only characters, such as directional isolates.
  ///
  /// These characters are invisible but still consume message length in SMS
  /// encodings, so they are stripped before measuring or transmitting text.
  ///
  /// Does **not** match ordinary whitespace or printable punctuation.
  ///
  /// Matches `\u2069` (pop directional isolate). Does not match: `a`.
  static final RegExp formattingOnly = RegExp(r'[\u2069\p{Cf}]', unicode: true);

  // ---------------------------------------------------------------------------
  // Digits and numeric input
  // ---------------------------------------------------------------------------

  /// Matches every character that is **not** a digit.
  ///
  /// Use it with `replaceAll` to reduce a formatted phone number to its digits.
  ///
  /// Does **not** match `0`-`9`.
  ///
  /// Matches `+`, ` `, `(`, and `)` in `+1 (415)`. Does not match: `1415`.
  static final RegExp nonDigits = RegExp(r'\D');

  /// Matches a literal plus sign anywhere in a value.
  ///
  /// Used to strip an existing international prefix marker before re-prefixing
  /// a phone number.
  ///
  /// Does **not** match other symbols.
  ///
  /// Matches the `+` in `+1415`. Does not match: `1415`.
  static final RegExp plusSign = RegExp(r'\+');

  /// Denies formatting characters in phone-number text input.
  ///
  /// Intended for `FilteringTextInputFormatter.deny`. Because `)-+` forms a
  /// character *range* inside the class, the effective denied set is
  /// whitespace, `(`, `)`, `*`, and `+`. This quirk is preserved intentionally
  /// so existing input behavior is unchanged.
  ///
  /// Does **not** deny digits or hyphens.
  ///
  /// Matches the space and `(` in `1 (415`. Does not match: `1415`.
  static final RegExp phoneDeniedInput = RegExp(r'[\s()-+]');

  /// Allows phone-number characters in text input.
  ///
  /// Intended for `FilteringTextInputFormatter.allow`. The `{0,15}` sequence is
  /// inside a character class, so it is treated as the literal characters
  /// `{`, `}`, `,`, `0`, `1`, and `5` rather than a quantifier; the effective
  /// allowed set is any digit plus `{`, `}`, and `,`. This quirk is preserved
  /// intentionally so existing input behavior is unchanged.
  ///
  /// Does **not** allow letters, spaces, or `+`.
  ///
  /// Matches `4` in `4a`. Does not match: `a`.
  static final RegExp phoneAllowedInput = RegExp(r'[\d{0,15}]');

  /// Allows the characters that make up a signed decimal number.
  ///
  /// Intended for `FilteringTextInputFormatter.allow` on double and currency
  /// fields.
  ///
  /// Does **not** allow exponent notation, thousands separators, or letters.
  ///
  /// Matches `-`, `1`, `.`, `5` in `-1.5`. Does not match: `1e5`'s `e`.
  static final RegExp decimalAllowedInput = RegExp(r'[\d.-]');

  /// Allows the characters that make up a signed integer.
  ///
  /// Intended for `FilteringTextInputFormatter.allow` on integer fields.
  ///
  /// Does **not** allow a decimal point.
  ///
  /// Matches `-` and `4` in `-4`. Does not match the `.` in `4.5`.
  static final RegExp intAllowedInput = RegExp(r'[\d-]');

  // ---------------------------------------------------------------------------
  // Sanitization, slugs, and identifiers
  // ---------------------------------------------------------------------------

  /// Matches a run of one or more characters that are not ASCII alphanumerics.
  ///
  /// Used to collapse arbitrary text into a separator-delimited identifier,
  /// such as a generated automation key.
  ///
  /// Does **not** match `a`-`z`, `A`-`Z`, or `0`-`9`, and it treats accented
  /// letters as non-alphanumeric.
  ///
  /// Matches ` - ` in `Save - Now`. Does not match: `SaveNow`.
  static final RegExp nonAlphanumericRun = RegExp(r'[^a-zA-Z0-9]+');

  /// Matches a single character that is neither a lowercase alphanumeric nor
  /// whitespace.
  ///
  /// Named to match the equivalent pattern in downstream consumers so they can
  /// drop their local copy.
  ///
  /// Used to strip punctuation from already-lowercased text while keeping word
  /// boundaries intact.
  ///
  /// Does **not** match spaces (so words stay separated) and, because it is
  /// lowercase-only, it *does* match uppercase letters — lowercase the input
  /// first.
  ///
  /// Matches the `!` in `hi there!`. Does not match the space in `hi there`.
  static final RegExp nonAlphanumeric = RegExp(r'[^a-z0-9\s]');

  /// Matches a value composed entirely of slug-safe characters.
  ///
  /// Accepts ASCII letters in either case, digits, hyphens, and underscores
  /// over the whole string.
  ///
  /// Does **not** match empty strings, spaces, dots, or slashes.
  ///
  /// Matches: `my-slug_1`. Does not match: `my slug`.
  static final RegExp slug = RegExp(r'^[A-Za-z0-9\-_]+$');

  /// Matches every character that may not appear in a generated slug.
  ///
  /// Use it with `replaceAll` to sanitize already-lowercased text into a slug.
  /// Because it is lowercase-only it also strips uppercase letters, so
  /// lowercase the input first.
  ///
  /// Does **not** match `a`-`z`, `0`-`9`, or `-`.
  ///
  /// Matches the space and `!` in `my slug!`. Does not match: `my-slug`.
  static final RegExp nonSlug = RegExp(r'[^a-z0-9-]');

  /// Matches a single leading forward slash.
  ///
  /// Used with `replaceFirst` to turn a route name such as `/settings` into a
  /// bare identifier segment.
  ///
  /// Does **not** match slashes elsewhere in the value.
  ///
  /// Matches the first `/` in `/a/b`. Does not match either slash in `a/b`.
  static final RegExp leadingSlash = RegExp(r'^/');

  /// Matches trailing sentence punctuation and closing brackets.
  ///
  /// Used to clean up a token that was extracted from prose, most often a URL
  /// captured by [urlInText].
  ///
  /// Does **not** match punctuation in the middle of the value.
  ///
  /// Matches the `).` at the end of `(see https://a.com).`.
  /// Does not match anything in `https://a.com/a.b`.
  static final RegExp trailingPunctuation = RegExp(r'[.,;)\]]+$');

  /// Matches characters that should be removed before comparing search terms.
  ///
  /// Word characters plus `@`, `.`, and `+` are preserved so that email
  /// addresses and international phone prefixes remain searchable.
  ///
  /// Does **not** match letters, digits, underscores, `@`, `.`, or `+`.
  ///
  /// Matches the space and `-` in `jane doe-1`. Does not match: `jane@a.com`.
  static final RegExp searchSanitize = RegExp(r'[^\w@.+]+');

  /// Matches digits and symbols that are not valid inside a person's name.
  ///
  /// Used to sanitize first- and last-name input as the user types.
  ///
  /// Does **not** match letters, spaces, hyphens, apostrophes, or accented
  /// characters, so international names are preserved.
  ///
  /// Matches the `1` and `#` in `Jane1#`. Does not match: `Jane O'Neil-Smith`.
  static final RegExp nameSanitize = RegExp(r'[0-9!@#$%^*()_+={}<>~]');

  /// Matches the separators used when pasting a list of values.
  ///
  /// Splitting on this handles clipboard content copied from a spreadsheet
  /// column, a spreadsheet row, or a comma-separated list.
  ///
  /// Does **not** match spaces or semicolons.
  ///
  /// Splits `a,b\nc` into `a`, `b`, `c`. Does not split `a b`.
  static final RegExp listSeparators = RegExp(r'[\n\t,]');

  // ---------------------------------------------------------------------------
  // Localization and templating
  // ---------------------------------------------------------------------------

  /// Matches a `{placeholder}` token in a localized or templated string.
  ///
  /// The match is non-greedy so consecutive tokens are captured individually,
  /// and `multiLine` is enabled so multi-line templates behave the same as
  /// single-line ones. `.` never matches a newline, so a token may not span
  /// lines.
  ///
  /// Does **not** match unbalanced braces or tokens broken across lines.
  ///
  /// Matches `{name}` and `{count}` in `Hi {name}, you have {count}`.
  /// Does not match: `Hi name`.
  static final RegExp placeholder = RegExp(r'{.*?}', multiLine: true);

  /// Matches a valid segment of a localization key path.
  ///
  /// Key paths are asserted against this before being resolved so malformed
  /// keys fail fast in debug builds.
  ///
  /// Does **not** match values made up only of spaces or punctuation.
  ///
  /// Matches: `alert--invalid-value`. Does not match: `   `.
  static final RegExp localizationKeyPath = RegExp(r'([a-zA-Z\d_-]+)');

  /// Matches runs of characters that are invalid in a normalized locale key.
  ///
  /// Used with `replaceAll` to strip anything other than ASCII letters, digits,
  /// and hyphens from a locale identifier.
  ///
  /// Does **not** match `a`-`z`, `A`-`Z`, `0`-`9`, or `-`. Note that
  /// underscores *are* matched and therefore removed.
  ///
  /// Matches the `_` in `en_US`. Does not match anything in `en-US`.
  static final RegExp invalidLocaleChars = RegExp(r'([^a-zA-Z\d-]+)');

  /// Matches an uppercase letter that directly follows a lowercase letter.
  ///
  /// The lookbehind keeps the preceding character out of the match, which makes
  /// it suitable for inserting a separator at camelCase word boundaries.
  ///
  /// Does **not** match a leading uppercase letter or an uppercase letter that
  /// follows another uppercase letter.
  ///
  /// Matches the `N` in `firstName`. Does not match the `A` in `ABTest`.
  static final RegExp camelCaseBoundary = RegExp(r'(?<=[a-z])[A-Z]');
}
