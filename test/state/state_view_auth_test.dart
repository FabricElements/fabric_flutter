import 'package:fabric_flutter/state/state_view_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StateViewAuth', () {
    group('defaults', () {
      test('should start with empty fields and section zero', () {
        // Arrange & Act
        final state = StateViewAuth();

        // Assert
        expect(state.phone, isNull);
        expect(state.phoneVerificationCode, isNull);
        expect(state.verificationId, isNull);
        expect(state.section, 0);
        expect(state.phoneValid, isNull);
      });
    });

    group('phone', () {
      test('should notify listeners when the value changes', () {
        // Arrange
        final state = StateViewAuth();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.phone = '+15551234567';

        // Assert
        expect(state.phone, '+15551234567');
        expect(notified, 1);
      });

      test('should not notify listeners when the value is unchanged', () {
        // Arrange
        final state = StateViewAuth();
        state.phone = '+15551234567';
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.phone = '+15551234567';

        // Assert
        expect(notified, 0);
      });
    });

    group('phoneValid', () {
      test(
        'should return the phone when it is longer than four characters',
        () {
          // Arrange
          final state = StateViewAuth();

          // Act
          state.phone = '+15551';

          // Assert
          expect(state.phoneValid, '+15551');
        },
      );

      test('should return null for a four character phone', () {
        // Arrange
        final state = StateViewAuth();

        // Act
        state.phone = '1234';

        // Assert
        expect(state.phoneValid, isNull);
      });

      test('should return null for an empty phone', () {
        // Arrange
        final state = StateViewAuth();

        // Act
        state.phone = '';

        // Assert
        expect(state.phoneValid, isNull);
      });
    });

    group('phoneVerificationCode', () {
      test('should notify listeners when the code changes', () {
        // Arrange
        final state = StateViewAuth();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.phoneVerificationCode = '123456';

        // Assert
        expect(state.phoneVerificationCode, '123456');
        expect(notified, 1);
      });

      test('should ignore a repeated assignment', () {
        // Arrange
        final state = StateViewAuth();
        state.phoneVerificationCode = '123456';
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.phoneVerificationCode = '123456';

        // Assert
        expect(notified, 0);
      });
    });

    group('verificationId', () {
      test('should notify listeners when the identifier changes', () {
        // Arrange
        final state = StateViewAuth();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.verificationId = 'verification-id';

        // Assert
        expect(state.verificationId, 'verification-id');
        expect(notified, 1);
      });

      test('should ignore a repeated assignment', () {
        // Arrange
        final state = StateViewAuth();
        state.verificationId = 'verification-id';
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.verificationId = 'verification-id';

        // Assert
        expect(notified, 0);
      });
    });

    group('section', () {
      test('should notify listeners when the section changes', () {
        // Arrange
        final state = StateViewAuth();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.section = 2;

        // Assert
        expect(state.section, 2);
        expect(notified, 1);
      });

      test('should ignore a repeated assignment', () {
        // Arrange
        final state = StateViewAuth();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.section = 0;

        // Assert
        expect(notified, 0);
      });
    });

    group('clear', () {
      test('should reset every field and notify listeners', () {
        // Arrange
        final state = StateViewAuth();
        state.phone = '+15551234567';
        state.phoneVerificationCode = '123456';
        state.verificationId = 'verification-id';
        state.section = 3;
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.clear();

        // Assert
        expect(state.phone, isNull);
        expect(state.phoneVerificationCode, isNull);
        expect(state.verificationId, isNull);
        expect(state.section, 0);
        expect(state.phoneValid, isNull);
        expect(notified, 1);
      });

      test('should notify even when the state is already empty', () {
        // Arrange
        final state = StateViewAuth();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.clear();

        // Assert
        expect(notified, 1);
      });
    });
  });
}
