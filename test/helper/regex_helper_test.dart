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
}
