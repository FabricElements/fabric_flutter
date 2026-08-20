import 'package:fabric_flutter/state/state_global.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('StateGlobal', () {
    group('packageInfo', () {
      test('should return an empty placeholder before initialization', () {
        // Arrange
        final state = StateGlobal();

        // Act
        final info = state.packageInfo;

        // Assert
        expect(info, isA<PackageInfo>());
        expect(info.appName, isEmpty);
        expect(info.packageName, isEmpty);
        expect(info.version, isEmpty);
        expect(info.buildNumber, isEmpty);
      });
    });

    group('appVersion', () {
      test('should return null before package metadata is available', () {
        // Arrange
        final state = StateGlobal();

        // Act
        final version = state.appVersion;

        // Assert
        expect(version, isNull);
      });
    });

    group('account', () {
      test('should default to null', () {
        // Arrange & Act
        final state = StateGlobal();

        // Assert
        expect(state.account, isNull);
      });

      test('should notify listeners when the account changes', () {
        // Arrange
        final state = StateGlobal();
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.account = 'account-1';

        // Assert
        expect(state.account, 'account-1');
        expect(notified, 1);
      });

      test('should not notify listeners for a repeated assignment', () {
        // Arrange
        final state = StateGlobal();
        state.account = 'account-1';
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.account = 'account-1';

        // Assert
        expect(notified, 0);
      });

      test('should allow clearing the account back to null', () {
        // Arrange
        final state = StateGlobal();
        state.account = 'account-1';
        var notified = 0;
        state.addListener(() => notified++);

        // Act
        state.account = null;

        // Assert
        expect(state.account, isNull);
        expect(notified, 1);
      });
    });

    group('connectivity', () {
      test('should assume the device is connected before any event', () {
        // Arrange & Act
        final state = StateGlobal();

        // Assert
        expect(state.connected, isTrue);
        expect(state.connectedTo, isNull);
      });

      test('should expose a broadcast connection stream', () async {
        // Arrange
        final state = StateGlobal();

        // Act
        final first = state.streamConnection.listen((_) {});
        final second = state.streamConnection.listen((_) {});

        // Assert: a broadcast stream accepts more than one subscriber.
        expect(first, isNotNull);
        expect(second, isNotNull);
        await first.cancel();
        await second.cancel();
      });
    });
  });
}
