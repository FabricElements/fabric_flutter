import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/input_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputValidation', () {
    group('isPhoneValid', () {
      test('should accept a valid E.164 number', () {
        // Arrange
        const phone = '+14155552671';

        // Act
        final result = InputValidation.isPhoneValid(phone);

        // Assert
        expect(result, isTrue);
      });

      test('should accept a national number using the default country', () {
        // Arrange
        const phone = '4155552671';

        // Act
        final result = InputValidation.isPhoneValid(phone);

        // Assert
        expect(result, isTrue);
      });

      test('should honor an explicit defaultCountry for national numbers', () {
        // Arrange
        const phone = '2079460958';

        // Act
        final result = InputValidation.isPhoneValid(
          phone,
          defaultCountry: 'GB',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should reject a number that is too short to be valid', () {
        // Arrange
        const phone = '123';

        // Act
        final result = InputValidation.isPhoneValid(phone);

        // Assert
        expect(result, isFalse);
      });

      test('should reject a non-numeric string', () {
        // Arrange
        const phone = 'abc';

        // Act
        final result = InputValidation.isPhoneValid(phone);

        // Assert
        expect(result, isFalse);
      });

      test('should reject an empty value', () {
        // Arrange
        const phone = '';

        // Act
        final result = InputValidation.isPhoneValid(phone);

        // Assert
        expect(result, isFalse);
      });

      test('should reject a null value', () {
        // Arrange
        const String? phone = null;

        // Act
        final result = InputValidation.isPhoneValid(phone);

        // Assert
        expect(result, isFalse);
      });
    });

    group('isPhoneValidNoPlusSign', () {
      test('should accept a digit-only number of valid length', () {
        // Arrange
        const phone = '14155552671';

        // Act
        final result = InputValidation.isPhoneValidNoPlusSign(phone);

        // Assert
        expect(result, isTrue);
      });

      test('should reject a number carrying a leading plus sign', () {
        // Arrange
        const phone = '+14155552671';

        // Act
        final result = InputValidation.isPhoneValidNoPlusSign(phone);

        // Assert
        expect(result, isFalse);
      });
    });

    group('validatePhone (English fallback)', () {
      const validation = InputValidation();

      test('should return null for a valid number', () {
        // Arrange
        const phone = '+14155552671';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, isNull);
      });

      test('should report an invalid country calling code', () {
        // Arrange
        const phone = '+9991234567';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'Enter a valid country calling code');
      });

      test('should report a non-numeric value', () {
        // Arrange
        const phone = 'abc';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'Enter a valid phone number');
      });

      test('should report a number that is too short', () {
        // Arrange
        const phone = '011';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'This phone number is too short');
      });

      test('should report a number that is too long', () {
        // Arrange
        const phone = '+1415555267123456789';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'This phone number is too long');
      });

      test('should return the generic message for an empty value', () {
        // Arrange
        const phone = '';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'Enter a valid phone number');
      });

      test('should return the generic message for a null value', () {
        // Arrange
        const String? phone = null;

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'Enter a valid phone number');
      });

      test('should validate a national number against defaultCountry', () {
        // Arrange
        const validationGb = InputValidation(defaultCountry: 'GB');

        // Act
        final result = validationGb.validatePhone('2079460958');

        // Assert
        expect(result, isNull);
      });

      test('should report a too short national number (parsed, not '
          'thrown)', () {
        // Arrange
        const phone = '415555';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'This phone number is too short');
      });

      test('should report a too long national number (parsed, not '
          'thrown)', () {
        // Arrange
        const phone = '41555526711234';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'This phone number is too long');
      });

      test('should treat a local-only national number as too short', () {
        // Arrange
        const validationGb = InputValidation(defaultCountry: 'GB');

        // Act
        final result = validationGb.validatePhone('20794609');

        // Assert
        expect(result, 'This phone number is too short');
      });

      test('should fall back to the generic message for a possible but '
          'invalid national number', () {
        // Arrange
        const phone = '1234567890';

        // Act
        final result = validation.validatePhone(phone);

        // Assert
        expect(result, 'Enter a valid phone number');
      });
    });

    group('validatePhone (localized Spanish messages)', () {
      late InputValidation validation;

      setUp(() async {
        // Arrange
        final locales = AppLocalizations(const Locale('es'));
        await locales.load();
        validation = InputValidation(locales: locales);
      });

      test('should localize the invalid country code message', () {
        // Act
        final result = validation.validatePhone('+9991234567');

        // Assert
        expect(result, 'Introduce un código de país válido');
      });

      test('should localize the too short message', () {
        // Act
        final result = validation.validatePhone('011');

        // Assert
        expect(result, 'Este número de teléfono es demasiado corto');
      });

      test('should localize a parsed too short national number', () {
        // Act
        final result = validation.validatePhone('415555');

        // Assert
        expect(result, 'Este número de teléfono es demasiado corto');
      });

      test('should localize a parsed too long national number', () {
        // Act
        final result = validation.validatePhone('41555526711234');

        // Assert
        expect(result, 'Este número de teléfono es demasiado largo');
      });

      test('should localize the too long message', () {
        // Act
        final result = validation.validatePhone('+1415555267123456789');

        // Assert
        expect(result, 'Este número de teléfono es demasiado largo');
      });

      test('should localize the generic message', () {
        // Act
        final result = validation.validatePhone('1234567890');

        // Assert
        expect(result, 'Introduce un número de teléfono válido');
      });
    });

    group('validatePhoneNoPlusSign', () {
      const validation = InputValidation();

      test('should return null for a digit-only number', () {
        // Act
        final result = validation.validatePhoneNoPlusSign('14155552671');

        // Assert
        expect(result, isNull);
      });

      test('should return a message for a number with a plus sign', () {
        // Act
        final result = validation.validatePhoneNoPlusSign('+14155552671');

        // Assert
        expect(result, 'Enter a valid phone number');
      });
    });

    group('validateEmail', () {
      const validation = InputValidation();

      test('should return null for a valid email', () {
        // Act & Assert
        expect(validation.validateEmail('user@example.com'), isNull);
      });

      test('should return a message for an invalid email', () {
        // Act & Assert
        expect(
          validation.validateEmail('not-an-email'),
          'Enter a valid email address',
        );
      });
    });

    group('validateUrl', () {
      const validation = InputValidation();

      test('should return null for a valid URL', () {
        // Act & Assert
        expect(validation.validateUrl('https://example.com'), isNull);
      });

      test('should return a message for an invalid URL', () {
        // Act & Assert
        expect(validation.validateUrl('not a url'), 'Enter a valid URL');
      });
    });

    group('isUsernameValid', () {
      test('should accept a lowercase alphanumeric handle', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid('user123'), isTrue);
      });

      test('should accept the minimum length of three characters', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid('abc'), isTrue);
      });

      test('should reject a handle shorter than three characters', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid('ab'), isFalse);
      });

      test('should reject a handle longer than thirty characters', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid('a' * 31), isFalse);
      });

      test('should reject uppercase letters', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid('UserName'), isFalse);
      });

      test('should reject whitespace and special characters', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid('user name'), isFalse);
        expect(InputValidation.isUsernameValid('user_name'), isFalse);
        expect(InputValidation.isUsernameValid('user.name'), isFalse);
      });

      test('should reject an empty value', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid(''), isFalse);
      });

      test('should reject a null value', () {
        // Act & Assert
        expect(InputValidation.isUsernameValid(null), isFalse);
      });
    });

    group('validateUsername', () {
      const validation = InputValidation();

      test('should return null for a valid username', () {
        // Act & Assert
        expect(validation.validateUsername('user123'), isNull);
      });

      test('should return the English fallback message for an invalid '
          'username', () {
        // Act & Assert
        expect(
          validation.validateUsername('Invalid Name'),
          'It must be 3-30 characters using only lowercase letters and numbers.',
        );
      });

      test('should localize the message in Spanish', () async {
        // Arrange
        final locales = AppLocalizations(const Locale('es'));
        await locales.load();
        final validationEs = InputValidation(locales: locales);

        // Act
        final result = validationEs.validateUsername('Invalid Name');

        // Assert
        expect(
          result,
          'Debe tener entre 3 y 30 caracteres usando solo letras minúsculas y '
          'números.',
        );
      });
    });

    group('validateNotEmpty', () {
      const validation = InputValidation();

      test('should return null when a value is present', () {
        // Act & Assert
        expect(validation.validateNotEmpty('value'), isNull);
      });

      test('should return a message when the value is empty', () {
        // Act & Assert
        expect(validation.validateNotEmpty(''), 'This field can\'t be empty');
      });
    });
  });
}
