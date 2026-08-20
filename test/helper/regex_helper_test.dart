import 'package:fabric_flutter/helper/regex_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegexHelper.email', () {
    test('should match a conventional email address', () {
      // Arrange, Act & Assert
      expect(RegexHelper.email.hasMatch('user@example.com'), isTrue);
    });

    test('should reject a string without an @ symbol', () {
      // Arrange, Act & Assert
      expect(RegexHelper.email.hasMatch('userexample.com'), isFalse);
    });

    test('should reject an email without a domain', () {
      // Arrange, Act & Assert
      expect(RegexHelper.email.hasMatch('user@'), isFalse);
    });
  });

  group('RegexHelper.phone', () {
    test('should match an E.164 style number with a leading plus', () {
      // Arrange, Act & Assert
      expect(RegexHelper.phone.hasMatch('+14155552671'), isTrue);
    });

    test('should reject a number that is missing the plus sign', () {
      // Arrange, Act & Assert
      expect(RegexHelper.phone.hasMatch('14155552671'), isFalse);
    });

    test('should reject a number that is too short', () {
      // Arrange, Act & Assert
      expect(RegexHelper.phone.hasMatch('+123'), isFalse);
    });
  });

  group('RegexHelper.phoneNoPlusSign', () {
    test('should match a digit-only number within the length range', () {
      // Arrange, Act & Assert
      expect(RegexHelper.phoneNoPlusSign.hasMatch('14155552671'), isTrue);
    });

    test('should reject a number that is too short', () {
      // Arrange, Act & Assert
      expect(RegexHelper.phoneNoPlusSign.hasMatch('1234'), isFalse);
    });
  });

  group('RegexHelper.url', () {
    test('should match an https URL', () {
      // Arrange, Act & Assert
      expect(RegexHelper.url.hasMatch('https://example.com'), isTrue);
    });

    test('should match an http URL with a path', () {
      // Arrange, Act & Assert
      expect(RegexHelper.url.hasMatch('http://example.com/path'), isTrue);
    });

    test('should reject a bare domain without a scheme', () {
      // Arrange, Act & Assert
      expect(RegexHelper.url.hasMatch('example.com'), isFalse);
    });
  });

  group('RegexHelper.password', () {
    test('should match a password meeting the strength policy', () {
      // Arrange, Act & Assert
      expect(RegexHelper.password.hasMatch('Str0ng!Pass'), isTrue);
    });

    test('should reject a password that is too short', () {
      // Arrange, Act & Assert
      expect(RegexHelper.password.hasMatch('Ab1!'), isFalse);
    });

    test('should reject a password without a special character', () {
      // Arrange, Act & Assert
      expect(RegexHelper.password.hasMatch('Str0ngPass'), isFalse);
    });

    test('should reject a password without an uppercase letter', () {
      // Arrange, Act & Assert
      expect(RegexHelper.password.hasMatch('str0ng!pass'), isFalse);
    });

    test('should reject a password without a digit', () {
      // Arrange, Act & Assert
      expect(RegexHelper.password.hasMatch('Strong!Pass'), isFalse);
    });
  });

  group('RegexHelper.username', () {
    test('should match a lowercase alphanumeric handle', () {
      // Arrange, Act & Assert
      expect(RegexHelper.username.hasMatch('user123'), isTrue);
    });

    test('should match the minimum length of three characters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.username.hasMatch('abc'), isTrue);
    });

    test('should match the maximum length of thirty characters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.username.hasMatch('a' * 30), isTrue);
    });

    test('should reject a handle shorter than three characters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.username.hasMatch('ab'), isFalse);
    });

    test('should reject a handle longer than thirty characters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.username.hasMatch('a' * 31), isFalse);
    });

    test('should reject uppercase letters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.username.hasMatch('UserName'), isFalse);
    });

    test('should reject whitespace and special characters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.username.hasMatch('user name'), isFalse);
      expect(RegexHelper.username.hasMatch('user_name'), isFalse);
      expect(RegexHelper.username.hasMatch('user.name'), isFalse);
    });
  });

  group('RegexHelper.uuid', () {
    test('should match a canonical hyphenated UUID', () {
      // Arrange, Act & Assert
      expect(
        RegexHelper.uuid.hasMatch('3f2504e0-4f89-11d3-9a0c-0305e82c3301'),
        isTrue,
      );
    });

    test('should reject a UUID without hyphens', () {
      // Arrange, Act & Assert
      expect(
        RegexHelper.uuid.hasMatch('3f2504e04f8911d39a0c0305e82c3301'),
        isFalse,
      );
    });
  });

  group('RegexHelper.urlInText', () {
    test('should pull a link out of free-form text', () {
      // Arrange
      const text = 'See https://example.com/a for details';

      // Act
      final match = RegexHelper.urlInText.firstMatch(text);

      // Assert
      expect(match?.group(0), 'https://example.com/a');
    });

    test('should not match a scheme-less domain', () {
      // Arrange, Act & Assert
      expect(RegexHelper.urlInText.hasMatch('see example.com'), isFalse);
    });
  });

  group('RegexHelper.mimePrimaryType', () {
    test('should capture the top-level media type', () {
      // Arrange, Act
      final match = RegexHelper.mimePrimaryType.firstMatch('image/png');

      // Assert
      expect(match?.group(1), 'image');
    });

    test('should reject a value without a subtype separator', () {
      // Arrange, Act & Assert
      expect(RegexHelper.mimePrimaryType.hasMatch('image'), isFalse);
    });
  });

  group('RegexHelper.htmlTag', () {
    test('should strip markup while keeping the text', () {
      // Arrange, Act
      final result = '<b>hi</b>'.replaceAll(RegexHelper.htmlTag, '');

      // Assert
      expect(result, 'hi');
    });

    test('should not match a bare comparison operator', () {
      // Arrange, Act & Assert
      expect(RegexHelper.htmlTag.hasMatch('a < b'), isFalse);
    });
  });

  group('RegexHelper.whitespace', () {
    test('should collapse mixed whitespace runs', () {
      // Arrange, Act
      final result = 'a  \t b'.replaceAll(RegexHelper.whitespace, ' ');

      // Assert
      expect(result, 'a b');
    });
  });

  group('RegexHelper.multipleSpaces', () {
    test('should collapse spaces without touching newlines', () {
      // Arrange, Act
      final result = 'a   b\n\nc'.replaceAll(RegexHelper.multipleSpaces, ' ');

      // Assert
      expect(result, 'a b\n\nc');
    });
  });

  group('RegexHelper.extraNewlines', () {
    test('should reduce three or more newlines to two', () {
      // Arrange, Act
      final result = 'a\n\n\n\nb'.replaceAll(RegexHelper.extraNewlines, '\n\n');

      // Assert
      expect(result, 'a\n\nb');
    });

    test('should leave a single blank line untouched', () {
      // Arrange, Act & Assert
      expect(RegexHelper.extraNewlines.hasMatch('a\n\nb'), isFalse);
    });
  });

  group('RegexHelper.formattingOnly', () {
    test('should strip an invisible directional isolate', () {
      // Arrange, Act
      final result = 'a\u2069b'.replaceAll(RegexHelper.formattingOnly, '');

      // Assert
      expect(result, 'ab');
    });

    test('should leave ordinary characters untouched', () {
      // Arrange, Act & Assert
      expect(RegexHelper.formattingOnly.hasMatch('a b'), isFalse);
    });
  });

  group('RegexHelper.nonDigits', () {
    test('should reduce a formatted phone number to digits', () {
      // Arrange, Act
      final result = '+1 (415) 555'.replaceAll(RegexHelper.nonDigits, '');

      // Assert
      expect(result, '1415555');
    });
  });

  group('RegexHelper.plusSign', () {
    test('should remove an international prefix marker', () {
      // Arrange, Act & Assert
      expect('+1415'.replaceAll(RegexHelper.plusSign, ''), '1415');
    });
  });

  group('RegexHelper.phoneDeniedInput', () {
    test('should match the formatting characters it denies', () {
      // Arrange, Act & Assert
      expect(RegexHelper.phoneDeniedInput.hasMatch('1 415'), isTrue);
      expect(RegexHelper.phoneDeniedInput.hasMatch('(415)'), isTrue);
      expect(RegexHelper.phoneDeniedInput.hasMatch('1415'), isFalse);
    });
  });

  group('RegexHelper.phoneAllowedInput', () {
    test('should allow digits and reject letters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.phoneAllowedInput.hasMatch('4'), isTrue);
      expect(RegexHelper.phoneAllowedInput.hasMatch('a'), isFalse);
    });
  });

  group('RegexHelper.decimalAllowedInput', () {
    test('should allow signed decimal characters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.decimalAllowedInput.hasMatch('.'), isTrue);
      expect(RegexHelper.decimalAllowedInput.hasMatch('-'), isTrue);
      expect(RegexHelper.decimalAllowedInput.hasMatch('e'), isFalse);
    });
  });

  group('RegexHelper.intAllowedInput', () {
    test('should allow digits and a sign but not a decimal point', () {
      // Arrange, Act & Assert
      expect(RegexHelper.intAllowedInput.hasMatch('-'), isTrue);
      expect(RegexHelper.intAllowedInput.hasMatch('4'), isTrue);
      expect(RegexHelper.intAllowedInput.hasMatch('.'), isFalse);
    });
  });

  group('RegexHelper.nonAlphanumericRun', () {
    test('should collapse separators into a single token boundary', () {
      // Arrange, Act
      final result = 'Save - Now'.replaceAll(
        RegexHelper.nonAlphanumericRun,
        '_',
      );

      // Assert
      expect(result, 'Save_Now');
    });
  });

  group('RegexHelper.nonAlphanumeric', () {
    test('should strip punctuation but keep spaces', () {
      // Arrange, Act
      final result = 'hi there!'.replaceAll(RegexHelper.nonAlphanumeric, '');

      // Assert
      expect(result, 'hi there');
    });
  });

  group('RegexHelper.slug', () {
    test('should match a slug-safe value', () {
      // Arrange, Act & Assert
      expect(RegexHelper.slug.hasMatch('my-slug_1'), isTrue);
    });

    test('should reject spaces and an empty value', () {
      // Arrange, Act & Assert
      expect(RegexHelper.slug.hasMatch('my slug'), isFalse);
      expect(RegexHelper.slug.hasMatch(''), isFalse);
    });
  });

  group('RegexHelper.nonSubdomain', () {
    test('should sanitize lowercased text into a slug', () {
      // Arrange, Act
      final result = 'my slug!'.replaceAll(RegexHelper.nonSubdomain, '-');

      // Assert
      expect(result, 'my-slug-');
    });
  });

  group('RegexHelper.leadingSlash', () {
    test('should strip only the first slash', () {
      // Arrange, Act & Assert
      expect('/a/b'.replaceFirst(RegexHelper.leadingSlash, ''), 'a/b');
    });
  });

  group('RegexHelper.trailingPunctuation', () {
    test('should trim trailing punctuation from an extracted token', () {
      // Arrange, Act
      final result = 'https://a.com/a).'.replaceAll(
        RegexHelper.trailingPunctuation,
        '',
      );

      // Assert
      expect(result, 'https://a.com/a');
    });

    test('should leave interior punctuation alone', () {
      // Arrange, Act & Assert
      expect(
        'https://a.com/a.b'.replaceAll(RegexHelper.trailingPunctuation, ''),
        'https://a.com/a.b',
      );
    });
  });

  group('RegexHelper.searchSanitize', () {
    test('should keep email and phone friendly characters', () {
      // Arrange, Act & Assert
      expect(
        'jane@a.com'.replaceAll(RegexHelper.searchSanitize, ''),
        'jane@a.com',
      );
      expect(
        'jane doe-1'.replaceAll(RegexHelper.searchSanitize, ''),
        'janedoe1',
      );
    });
  });

  group('RegexHelper.nameSanitize', () {
    test('should strip digits and symbols from a name', () {
      // Arrange, Act & Assert
      expect('Jane1#'.replaceAll(RegexHelper.nameSanitize, ''), 'Jane');
    });

    test('should preserve hyphens, apostrophes, and spaces', () {
      // Arrange, Act & Assert
      expect(
        "Jane O'Neil-Smith".replaceAll(RegexHelper.nameSanitize, ''),
        "Jane O'Neil-Smith",
      );
    });
  });

  group('RegexHelper.listSeparators', () {
    test('should split on commas, newlines, and tabs', () {
      // Arrange, Act
      final result = 'a,b\nc\td'.split(RegexHelper.listSeparators);

      // Assert
      expect(result, ['a', 'b', 'c', 'd']);
    });
  });

  group('RegexHelper.placeholder', () {
    test('should match each token individually', () {
      // Arrange, Act
      final matches = RegexHelper.placeholder
          .allMatches('Hi {name}, you have {count}')
          .map((e) => e.group(0))
          .toList();

      // Assert
      expect(matches, ['{name}', '{count}']);
    });

    test('should match tokens across multiple lines', () {
      // Arrange, Act
      final matches = RegexHelper.placeholder.allMatches('{a}\n{b}').length;

      // Assert
      expect(matches, 2);
    });
  });

  group('RegexHelper.localizationKeyPath', () {
    test('should match a conventional key path', () {
      // Arrange, Act & Assert
      expect(
        RegexHelper.localizationKeyPath.hasMatch('alert--invalid-value'),
        isTrue,
      );
    });

    test('should reject a whitespace-only key', () {
      // Arrange, Act & Assert
      expect(RegexHelper.localizationKeyPath.hasMatch('   '), isFalse);
    });
  });

  group('RegexHelper.invalidLocaleChars', () {
    test('should strip an underscore separator', () {
      // Arrange, Act & Assert
      expect('en_US'.replaceAll(RegexHelper.invalidLocaleChars, ''), 'enUS');
    });

    test('should leave a hyphenated locale untouched', () {
      // Arrange, Act & Assert
      expect('en-US'.replaceAll(RegexHelper.invalidLocaleChars, ''), 'en-US');
    });
  });

  group('RegexHelper.camelCaseBoundary', () {
    test('should find the boundary in a camelCase identifier', () {
      // Arrange, Act
      final result = 'firstName'.replaceAllMapped(
        RegexHelper.camelCaseBoundary,
        (m) => '-${m.group(0)}',
      );

      // Assert
      expect(result, 'first-Name');
    });

    test('should not match consecutive uppercase letters', () {
      // Arrange, Act & Assert
      expect(RegexHelper.camelCaseBoundary.hasMatch('ABTest'), isFalse);
    });
  });

  group('RegexHelper.urlStrict', () {
    test('should match well-formed URLs end to end', () {
      // Arrange
      const valid = [
        'https://example.com',
        'http://example.com/path',
        'https://example.com/a?b=c#d',
        'https://sub.example.co.uk/x',
      ];

      // Act & Assert
      for (final value in valid) {
        expect(RegexHelper.urlStrict.hasMatch(value), isTrue, reason: value);
      }
    });

    test('should reject a URL embedded in surrounding text', () {
      // Arrange
      const invalid = [
        'garbage https://example.com',
        'xhttps://example.com',
        'https://example.com trailing junk',
        'example.com',
        'ftp://example.com',
        '',
      ];

      // Act & Assert
      for (final value in invalid) {
        expect(RegexHelper.urlStrict.hasMatch(value), isFalse, reason: value);
      }
    });

    test('should match long modern top-level domains', () {
      // Arrange: the TLD label allows up to the DNS maximum of 63 characters,
      // so anything past the legacy 6-character cap must still validate.
      const valid = [
        'https://example.agency',
        'https://example.digital',
        'https://example.services',
        'https://example.technology',
        'https://example.photography',
        'https://a.international/path?x=1',
      ];

      // Act & Assert
      for (final value in valid) {
        expect(RegexHelper.urlStrict.hasMatch(value), isTrue, reason: value);
      }
    });

    test('should reject a single-character top-level domain', () {
      // Arrange, Act & Assert
      expect(RegexHelper.urlStrict.hasMatch('https://example.c'), isFalse);
    });

    test('should be stricter than the legacy unanchored url pattern', () {
      // Arrange
      const embedded = 'garbage https://example.com';

      // Act & Assert
      expect(RegexHelper.url.hasMatch(embedded), isTrue);
      expect(RegexHelper.urlStrict.hasMatch(embedded), isFalse);
    });
  });

  group('RegexHelper.slugAfterSlash', () {
    test('should capture the path segment after a leading slash', () {
      // Arrange, Act
      final match = RegexHelper.slugAfterSlash.firstMatch('/settings/profile');

      // Assert
      expect(match?.group(1), 'settings/profile');
    });

    test('should stop at the first whitespace character', () {
      // Arrange, Act
      final match = RegexHelper.slugAfterSlash.firstMatch('/settings profile');

      // Assert
      expect(match?.group(1), 'settings');
    });

    test('should not match a value without a leading slash', () {
      // Arrange, Act & Assert
      expect(RegexHelper.slugAfterSlash.hasMatch('settings'), isFalse);
    });
  });

  group('RegexHelper.slug versus RegexHelper.username', () {
    test('should keep the two identifier patterns distinct', () {
      // Arrange
      const mixedCase = 'My-Slug_1';
      const shortHandle = 'ab';

      // Act & Assert
      expect(RegexHelper.slug.hasMatch(mixedCase), isTrue);
      expect(RegexHelper.username.hasMatch(mixedCase), isFalse);
      expect(RegexHelper.slug.hasMatch(shortHandle), isTrue);
      expect(RegexHelper.username.hasMatch(shortHandle), isFalse);
    });
  });
}
