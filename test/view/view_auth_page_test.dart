import 'package:fabric_flutter/component/phone_input.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/state/state_analytics.dart';
import 'package:fabric_flutter/state/state_global.dart';
import 'package:fabric_flutter/state/state_view_auth.dart';
import 'package:fabric_flutter/view/view_auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/firebase_test_harness.dart';

/// Mounts [ViewAuthPage] with the providers and localizations it reads.
///
/// [connected] seeds [StateGlobal.connected]; the page shows its loader until a
/// device is connected. [state] lets a test drive the auth-flow section before
/// or after mounting. The returned future settles the 500ms post-frame delay
/// the page uses to flip its private `initialized` flag, so callers land on the
/// fully rendered page rather than the loading screen.
Future<StateViewAuth> _pumpAuth(
  WidgetTester tester, {
  bool connected = true,
  StateViewAuth? state,
  bool phone = false,
  bool google = false,
  bool anonymous = false,
  String? title,
  bool settle = true,
}) async {
  final global = StateGlobal()..connected = connected;
  final viewAuth = state ?? StateViewAuth();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<StateGlobal>.value(value: global),
        ChangeNotifierProvider<StateAnalytics>.value(value: StateAnalytics()),
        ChangeNotifierProvider<StateViewAuth>.value(value: viewAuth),
      ],
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
        supportedLocales: const [Locale('en', 'US')],
        home: ViewAuthPage(
          url: 'https://example.com/auth',
          phone: phone,
          google: google,
          anonymous: anonymous,
          title: title,
        ),
      ),
    ),
  );
  // The page registers a post-frame callback on its first build, then awaits a
  // 500ms delay before flipping its private `initialized` flag. Pump the first
  // frame so the callback is scheduled, advance past the delay, then settle the
  // rebuild so the page leaves its loading screen.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  // The loading screen animates indefinitely, so only settle when the page is
  // expected to leave it (i.e. when the device is connected).
  if (settle) {
    await tester.pumpAndSettle();
  }
  return viewAuth;
}

void main() {
  setUpAll(() async {
    await setupFirebaseForTest();
  });

  group('ViewAuthPage', () {
    group('connectivity gating', () {
      testWidgets('should show the loader while the device is offline', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pumpAuth(
          tester,
          connected: false,
          anonymous: true,
          settle: false,
        );

        // Assert – offline never reaches the home section buttons.
        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('should render the home section once connected', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pumpAuth(tester, anonymous: true, title: 'Sign in here');

        // Assert
        expect(find.text('Sign in here'), findsOneWidget);
      });
    });

    group('provider gating of sign-in options', () {
      testWidgets('should render an anonymous button when enabled', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pumpAuth(tester, anonymous: true);

        // Assert
        expect(find.byType(FilledButton), findsWidgets);
      });

      testWidgets('should render no auth buttons when all providers are off', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pumpAuth(tester);

        // Assert
        expect(find.byType(FilledButton), findsNothing);
      });
    });

    group('section transitions', () {
      testWidgets('should surface the phone input on section 1', (
        WidgetTester tester,
      ) async {
        // Arrange
        final state = StateViewAuth()..section = 1;

        // Act
        await _pumpAuth(tester, phone: true, state: state);

        // Assert – the IndexedStack keeps every section mounted, so the phone
        // input is present and section 1 is selected.
        expect(find.byType(PhoneInput), findsOneWidget);
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 1);
      });

      testWidgets('should select section 2 for verification-code entry', (
        WidgetTester tester,
      ) async {
        // Arrange
        final state = StateViewAuth()..section = 2;

        // Act
        await _pumpAuth(tester, phone: true, state: state);

        // Assert
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 2);
      });

      testWidgets('should default to the home section', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        final state = await _pumpAuth(tester, phone: true);

        // Assert
        expect(state.section, 0);
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 0);
      });
    });
  });
}
