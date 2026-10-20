import 'package:fabric_flutter/state/state_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/firebase_test_harness.dart';

/// Stands in for the messaging plugin so the permission and token flow can be
/// exercised without a platform channel.
///
/// Every seam records how often it was reached, which is what lets the tests
/// assert that the permission prompt and the token fetch happen once per
/// session rather than on every signed-in stream event.
class _FakeNotifications extends StateNotifications {
  _FakeNotifications({
    this.status = AuthorizationStatus.authorized,
    this.apnsToken = 'apns-token',
    this.fcmToken = 'fcm-token',
    this.permissionError,
    this.apnsError,
  });

  /// Status reported by the permission request.
  final AuthorizationStatus status;

  /// Apple push token returned by the APNS lookup.
  final String? apnsToken;

  /// Registration token returned by the FCM lookup.
  final String? fcmToken;

  /// When set, the permission request throws it instead of returning [status].
  ///
  /// Cleared after the first throw so a retry can succeed.
  Object? permissionError;

  /// When set, the APNS lookup throws it instead of returning [apnsToken].
  final Object? apnsError;

  /// Counts how many times the permission request ran.
  int permissionRequests = 0;

  /// Counts how many times the APNS token lookup ran.
  int apnsRequests = 0;

  /// Counts how many times the FCM token lookup ran.
  int tokenRequests = 0;

  @override
  Future<AuthorizationStatus> requestPermission() async {
    permissionRequests++;
    final error = permissionError;
    if (error != null) {
      permissionError = null;
      throw error;
    }
    return status;
  }

  @override
  Future<String?> getApnsToken() async {
    apnsRequests++;
    final error = apnsError;
    if (error != null) throw error;
    return apnsToken;
  }

  @override
  Future<String?> getFcmToken() async {
    tokenRequests++;
    return fcmToken;
  }
}

void main() {
  group('StateNotifications', () {
    group('getToken', () {
      late List<String> logs;
      late void Function(String?, {int? wrapWidth}) originalDebugPrint;

      setUpAll(setupFirebaseForTest);

      setUp(() {
        logs = <String>[];
        originalDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          logs.add(message ?? '');
        };
      });

      tearDown(() => debugPrint = originalDebugPrint);

      test('should request permission and fetch the token once', () async {
        // Arrange
        final state = _FakeNotifications();

        // Act
        final first = await state.getToken();
        final second = await state.getToken();

        // Assert
        expect(first, 'fcm-token');
        expect(second, 'fcm-token');
        expect(state.permissionRequests, 1);
        expect(state.apnsRequests, 1);
        expect(state.tokenRequests, 1);
      });

      test('should print the granted permission once', () async {
        // Arrange
        final state = _FakeNotifications();

        // Act
        await state.getToken();
        await state.getToken();

        // Assert
        expect(
          logs.where((log) => log.contains('User granted permission')),
          hasLength(1),
        );
      });

      test(
        'should share one in-flight request between concurrent callers',
        () async {
          // Arrange
          final state = _FakeNotifications();

          // Act
          final results = await Future.wait([
            state.getToken(),
            state.getToken(),
            state.getToken(),
          ]);

          // Assert
          expect(results, everyElement('fcm-token'));
          expect(state.permissionRequests, 1);
          expect(state.tokenRequests, 1);
        },
      );

      test('should return null when permission is denied', () async {
        // Arrange
        final state = _FakeNotifications(status: AuthorizationStatus.denied);

        // Act
        final token = await state.getToken();

        // Assert
        expect(token, isNull);
        expect(state.permissionRequests, 1);
        expect(state.apnsRequests, 0);
        expect(state.tokenRequests, 0);
      });

      test('should return null when the APNS token lookup fails', () async {
        // Arrange
        final state = _FakeNotifications(apnsError: 'no apns token');

        // Act
        final token = await state.getToken();

        // Assert
        expect(token, isNull);
        expect(state.tokenRequests, 0);
      });

      test('should retry after a failed permission request', () async {
        // Arrange
        final state = _FakeNotifications(permissionError: 'permission failed');

        // Act
        await expectLater(state.getToken(), throwsA('permission failed'));
        final retried = await state.getToken();

        // Assert
        expect(retried, 'fcm-token');
        expect(state.permissionRequests, 2);
      });

      test('should request again after reset', () async {
        // Arrange
        final state = _FakeNotifications();
        await state.getToken();

        // Act
        state.reset();
        final token = await state.getToken();

        // Assert
        expect(token, 'fcm-token');
        expect(state.permissionRequests, 2);
      });

      test('should return the token supplied by the plugin', () async {
        // Arrange
        final state = _FakeNotifications(
          apnsToken: 'custom-apns',
          fcmToken: 'custom-fcm',
        );

        // Act
        final token = await state.getToken();

        // Assert
        expect(token, 'custom-fcm');
        expect(state.apnsRequests, 1);
        expect(state.tokenRequests, 1);
      });

      test('should throw when Firebase is not initialized', () async {
        // Arrange
        final state = _FakeNotifications()..initialized = false;

        // Act & Assert
        await expectLater(
          state.getToken(),
          throwsA('Initialize Firebase app first'),
        );
        expect(state.permissionRequests, 0);
      });
    });
  });
}
