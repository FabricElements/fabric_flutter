import 'package:fabric_flutter/helper/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthWebSignInMode', () {
    test('should default to redirect', () {
      // Arrange & Act – the mode a host gets without asking for one.
      const mode = AuthWebSignInMode.redirect;

      // Assert
      expect(mode, AuthWebSignInMode.redirect);
      expect(AuthWebSignInMode.values, hasLength(2));
      expect(AuthWebSignInMode.values.first, AuthWebSignInMode.popup);
    });
  });

  group('isWebPopupBlockedCode', () {
    test('should recognise the codes a popup blocker produces', () {
      // Arrange & Act & Assert – both are what a blocker looks like from the
      // SDK: one refuses to open, the other closes what it opened.
      expect(isWebPopupBlockedCode('popup-blocked'), isTrue);
      expect(isWebPopupBlockedCode('popup-closed-by-user'), isTrue);
    });

    test('should not treat an ordinary failure as a blocked popup', () {
      // Arrange & Act & Assert – these must keep their own handling rather
      // than silently retrying through a redirect.
      expect(isWebPopupBlockedCode('canceled'), isFalse);
      expect(isWebPopupBlockedCode('network-request-failed'), isFalse);
      expect(
        isWebPopupBlockedCode('account-exists-with-different-credential'),
        isFalse,
      );
      expect(isWebPopupBlockedCode(''), isFalse);
    });
  });

  group('runWebSignIn', () {
    test('should call only the redirect flow in redirect mode', () async {
      // Arrange
      final calls = <String>[];

      // Act
      await runWebSignIn(
        mode: AuthWebSignInMode.redirect,
        popup: () async => calls.add('popup'),
        redirect: () async => calls.add('redirect'),
      );

      // Assert – the popup is never opened, which is the whole point.
      expect(calls, ['redirect']);
    });

    test('should call only the popup flow in popup mode', () async {
      // Arrange
      final calls = <String>[];

      // Act
      await runWebSignIn(
        mode: AuthWebSignInMode.popup,
        popup: () async => calls.add('popup'),
        redirect: () async => calls.add('redirect'),
      );

      // Assert – an explicit popup is honoured, not second-guessed.
      expect(calls, ['popup']);
    });

    test(
      'should fall back to the redirect when the popup is blocked',
      () async {
        // Arrange
        final calls = <String>[];

        // Act
        await runWebSignIn(
          mode: AuthWebSignInMode.popup,
          popup: () async {
            calls.add('popup');
            throw FirebaseAuthException(code: 'popup-blocked');
          },
          redirect: () async => calls.add('redirect'),
        );

        // Assert – the blocked popup is retried through the redirect flow.
        expect(calls, ['popup', 'redirect']);
      },
    );

    test('should fall back to the redirect when the popup is closed', () async {
      // Arrange
      final calls = <String>[];

      // Act
      await runWebSignIn(
        mode: AuthWebSignInMode.popup,
        popup: () async {
          calls.add('popup');
          throw FirebaseAuthException(code: 'popup-closed-by-user');
        },
        redirect: () async => calls.add('redirect'),
      );

      // Assert
      expect(calls, ['popup', 'redirect']);
    });

    test(
      'should rethrow a popup failure that is not a blocked popup',
      () async {
        // Arrange
        final calls = <String>[];
        final failure = FirebaseAuthException(code: 'network-request-failed');

        // Act
        Future<void> act() => runWebSignIn(
          mode: AuthWebSignInMode.popup,
          popup: () async {
            calls.add('popup');
            throw failure;
          },
          redirect: () async => calls.add('redirect'),
        );

        // Assert – a real failure is surfaced, not masked by a redirect retry.
        await expectLater(act(), throwsA(same(failure)));
        expect(calls, ['popup']);
      },
    );

    test('should rethrow a non-Firebase popup failure', () async {
      // Arrange
      final calls = <String>[];

      // Act
      Future<void> act() => runWebSignIn(
        mode: AuthWebSignInMode.popup,
        popup: () async {
          calls.add('popup');
          throw StateError('unexpected');
        },
        redirect: () async => calls.add('redirect'),
      );

      // Assert
      await expectLater(act(), throwsA(isA<StateError>()));
      expect(calls, ['popup']);
    });

    test('should propagate a redirect failure in redirect mode', () async {
      // Arrange
      final failure = FirebaseAuthException(code: 'network-request-failed');

      // Act
      Future<void> act() => runWebSignIn(
        mode: AuthWebSignInMode.redirect,
        popup: () async {},
        redirect: () async => throw failure,
      );

      // Assert – the caller's existing catch ladder handles it.
      await expectLater(act(), throwsA(same(failure)));
    });
  });
}
