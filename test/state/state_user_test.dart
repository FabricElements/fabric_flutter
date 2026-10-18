import 'package:fabric_flutter/component/route_page.dart';
import 'package:fabric_flutter/helper/route_helper.dart';
import 'package:fabric_flutter/serialized/user_status.dart';
import 'package:fabric_flutter/state/state_global.dart';
import 'package:fabric_flutter/state/state_notifications.dart';
import 'package:fabric_flutter/state/state_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/firebase_test_harness.dart';

void main() {
  group('StateUser', () {
    setUp(() async {
      // Arrange: mock Firebase so StateUser singletons resolve.
      await setupFirebaseForTest();
    });

    test('serialized reflects the id stored in data', () {
      // Arrange
      final state = StateUser();

      // Act
      state.data = {'id': 'user-123', 'firstName': 'Ada'};

      // Assert
      expect(state.serialized.id, 'user-123');
      expect(state.serialized.firstName, 'Ada');
    });

    test('serialized returns an empty user when data is null', () {
      // Arrange
      final state = StateUser();

      // Act
      final user = state.serialized;

      // Assert
      expect(user.id, isNull);
      expect(user.firstName, isNull);
    });

    test('serialized reuses the cached instance for the same data', () {
      // Arrange
      final state = StateUser();
      state.data = {'id': 'user-123', 'firstName': 'Ada'};

      // Act
      final first = state.serialized;
      final second = state.serialized;

      // Assert: identical instance means no rebuild via fromJson occurred.
      expect(identical(first, second), isTrue);
    });

    test('serialized rebuilds when data is replaced', () {
      // Arrange
      final state = StateUser();
      state.data = {'id': 'user-123', 'firstName': 'Ada'};
      final first = state.serialized;

      // Act
      state.data = {'id': 'user-456', 'firstName': 'Grace'};
      final second = state.serialized;

      // Assert
      expect(identical(first, second), isFalse);
      expect(second.id, 'user-456');
    });

    group('serialized deserialization error handling', () {
      test('sets error when fromJson throws on invalid enum value', () {
        // Arrange
        final state = StateUser();
        // os field has no unknownEnumValue, so invalid value will throw
        state.data = {'id': 'user-123', 'os': 'invalid-os-value'};

        // Act
        final _ = state.serialized;

        // Assert
        expect(state.error, isNotNull);
        expect(state.error, contains('Invalid'));
      });

      test('returns a fallback user when deserialization fails', () {
        // Arrange
        final state = StateUser();
        state.data = {'id': 'user-123', 'os': 'invalid-os-value'};

        // Act
        final user = state.serialized;

        // Assert: fallback has default values but still looks valid
        expect(user.role, 'unknown');
        expect(user.id, isNull);
        expect(user.firstName, isNull);
      });

      test('sets hadSerializationError flag on deserialization failure', () {
        // Arrange
        final state = StateUser();
        state.data = {'id': 'user-123', 'os': 'invalid-os-value'};

        // Act
        final _ = state.serialized;

        // Assert
        expect(state.hadSerializationError, isTrue);
      });

      test(
        'reports deserialization error on repeated reads of same failure',
        () {
          // Arrange
          final state = StateUser();
          state.data = {'id': 'user-123', 'os': 'invalid-os-value'};
          List<bool> errorFlags = [];

          // Act
          final _ = state.serialized; // First read
          errorFlags.add(state.hadSerializationError);

          state.serialized; // Second read of same data
          errorFlags.add(state.hadSerializationError);

          // Assert - hadSerializationError flag is set on every read
          expect(errorFlags.length, 2);
          expect(
            errorFlags.every((flag) => flag),
            isTrue,
            reason:
                'hadSerializationError flag should be true on every read of '
                'deserialization failure, not dedup\'d away',
          );
        },
      );
    });

    group('userStatus.ready guards against spinner-on-refresh', () {
      /// Builds a minimal [RouteHelper] for use in the ready-state tests.
      RouteHelper buildTestRouteHelper() {
        return RouteHelper(
          publicRoutes: const ['/'],
          authenticatedRoutes: const ['/home'],
          adminRoutes: const ['/admin'],
          authRoute: '/auth',
          unknownRoute: '/',
          initialRoute: '/',
          routeMap: {
            '/': const Scaffold(body: Text('public')),
            '/auth': const Scaffold(body: Text('auth')),
            '/home': const Scaffold(body: Text('home')),
            '/admin': const Scaffold(body: Text('admin')),
          },
        );
      }

      /// Regression: before the fix, [_refreshAuth] unconditionally set
      /// [_ready] = false on every [userChanges()] re-emit (token refresh
      /// ~every 60 min, Firestore user-doc ping writes).  RoutePage's
      /// `if (!status.ready) return widget.loading` replaced the entire
      /// route content with a spinner for ~3.5 s each time.  The fix only
      /// transitions [ready] to false on genuine identity changes.

      /// Wraps [child] with the providers RoutePage reads during listener
      /// configuration so the test doesn't hit a ProviderNotFoundException.
      Widget wrapWithProviders(Widget child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => StateGlobal()),
            ChangeNotifierProvider(create: (_) => StateNotifications()),
          ],
          child: child,
        );
      }

      testWidgets('RoutePage shows content when userStatus.ready is true', (
        tester,
      ) async {
        // Arrange
        final readyStatus = UserStatus(signedIn: true, ready: true);
        final page = RoutePage(
          routeHelper: buildTestRouteHelper(),
          uri: Uri.parse('/'),
          status: readyStatus,
          onInit: () async {},
          onContextReady: (_) {},
        );

        // Act
        await tester.pumpWidget(
          wrapWithProviders(MaterialApp(home: Scaffold(body: page))),
        );
        // Pump past the _initFuture 300 ms delay so the FutureBuilder resolves.
        await tester.pump(const Duration(milliseconds: 400));

        // Assert: the loading spinner must NOT appear.
        expect(
          find.byKey(const Key('route-page-loading')),
          findsNothing,
          reason:
              'LoadingScreen must not appear when userStatus.ready is true.',
        );

        // Assert: the route content area (GestureDetector) is present.
        expect(
          find.byKey(const ValueKey('route-page-gesture-detector')),
          findsOneWidget,
          reason:
              'Route content must be present when userStatus.ready is true.',
        );
      });

      testWidgets('RoutePage shows loading when userStatus.ready is false', (
        tester,
      ) async {
        // Arrange
        final notReadyStatus = UserStatus(ready: false);
        final page = RoutePage(
          routeHelper: buildTestRouteHelper(),
          uri: Uri.parse('/'),
          status: notReadyStatus,
          onInit: () async {},
          onContextReady: (_) {},
        );

        // Act
        await tester.pumpWidget(
          wrapWithProviders(MaterialApp(home: Scaffold(body: page))),
        );
        // Advance past the 300 ms _initFuture timer so it doesn't trigger the
        // "timer still pending" check when the widget tree is disposed.
        await tester.pump(const Duration(milliseconds: 400));

        // Assert: the loading spinner MUST appear even after the future completes,
        // because status is the primary guard — not the future.
        expect(
          find.byKey(const Key('route-page-loading')),
          findsOneWidget,
          reason: 'LoadingScreen must appear when userStatus.ready is false.',
        );
      });

      testWidgets('RoutePage shows loading when status is null', (
        tester,
      ) async {
        // Arrange
        final page = RoutePage(
          routeHelper: buildTestRouteHelper(),
          uri: Uri.parse('/'),
          status: null,
          onInit: () async {},
          onContextReady: (_) {},
        );

        // Act
        await tester.pumpWidget(
          wrapWithProviders(MaterialApp(home: Scaffold(body: page))),
        );
        // Advance past the 300 ms _initFuture timer so it doesn't trigger the
        // "timer still pending" check when the widget tree is disposed.
        await tester.pump(const Duration(milliseconds: 400));

        // Assert: the loading spinner MUST appear.
        expect(
          find.byKey(const Key('route-page-loading')),
          findsOneWidget,
          reason: 'LoadingScreen must appear when userStatus is null.',
        );
      });
    });
  });
}
