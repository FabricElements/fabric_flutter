import 'dart:async';

import 'package:fabric_flutter/component/phone_input.dart';
import 'package:fabric_flutter/helper/app_global.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/state/state_analytics.dart';
import 'package:fabric_flutter/state/state_global.dart';
import 'package:fabric_flutter/state/state_view_auth.dart';
import 'package:fabric_flutter/view/view_auth_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/firebase_test_harness.dart';

/// Fakes [AuthService] so the page's sign-in branches become reachable.
///
/// [AuthService] is reached through `view_auth_page.dart`, which re-exports the
/// seam, so this also pins that the re-export keeps a single import working.
///
/// The real service can never fail on demand in a widget test: under the
/// mocked Firebase method channel `signInAnonymously` simply never completes,
/// so the `catch` blocks are dead code. This double either throws [error] or
/// waits on [pending], which is what lets the failure and mid-flight-dispose
/// paths be exercised.
class _FakeAuthService implements AuthService {
  /// Throws this object from every seam method when set.
  Object? error;

  /// Blocks every seam method until completed when set.
  Completer<void>? pending;

  /// Records the name of every seam method that was invoked, in order.
  final List<String> calls = <String>[];

  /// Applies the configured behavior for the seam method named [name].
  Future<void> _run(String name) async {
    calls.add(name);
    final blocker = pending;
    if (blocker != null) await blocker.future;
    final failure = error;
    if (failure != null) throw failure;
  }

  @override
  Future<void> signInAnonymously() => _run('signInAnonymously');

  @override
  Future<void> signInWithApple() => _run('signInWithApple');

  @override
  Future<void> signInWithGoogle({required List<String> scopes}) =>
      _run('signInWithGoogle');

  @override
  Future<String> signInWithPhoneNumber(String phoneNumber) async {
    await _run('signInWithPhoneNumber');
    return 'verification-id';
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) => _run('verifyPhoneNumber');

  @override
  Future<void> confirmPhoneCode(String smsCode) => _run('confirmPhoneCode');

  @override
  Future<void> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) => _run('signInWithPhoneCredential');

  @override
  Future<void> signInWithCredential(AuthCredential credential) =>
      _run('signInWithCredential');
}

/// Mounts [ViewAuthPage] with the providers and localizations it reads.
///
/// [connected] seeds [StateGlobal.connected]; the page shows its loader until a
/// device is connected. [state] lets a test drive the auth-flow section before
/// or after mounting. [authService] replaces the Firebase backend so sign-in
/// results can be controlled. The navigator and scaffold-messenger keys are
/// wired the way consumers must wire them, because the page's failure alerts
/// are raised without a context and resolve the root one instead. The returned
/// future settles the 500ms post-frame delay the page uses to flip its private
/// `initialized` flag, so callers land on the fully rendered page rather than
/// the loading screen.
Future<StateViewAuth> _pumpAuth(
  WidgetTester tester, {
  bool connected = true,
  StateViewAuth? state,
  bool phone = false,
  bool google = false,
  bool anonymous = false,
  String? title,
  bool settle = true,
  AuthService? authService,
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
        navigatorKey: AppGlobal.navigatorKey,
        scaffoldMessengerKey: AppGlobal.snackbarKey,
        localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
        supportedLocales: const [Locale('en', 'US')],
        home: ViewAuthPage(
          url: 'https://example.com/auth',
          phone: phone,
          google: google,
          anonymous: anonymous,
          title: title,
          authService: authService,
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

/// Advances enough frames for an awaited seam call and its alert to render.
///
/// The alert is presented through the app-level [ScaffoldMessenger], so it
/// needs a frame after the future resolves and another for the snackbar
/// entrance animation.
Future<void> _settleAlert(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 750));
}

void main() {
  setUpAll(() async {
    await setupFirebaseForTest();
  });

  setUp(() {
    // A GlobalKey cannot be attached to two trees, and a key left over from a
    // torn-down pump would still resolve, so each test needs a pristine one.
    AppGlobal.navigatorKey = GlobalKey<NavigatorState>();
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

    group('anonymous sign-in through the injected service', () {
      testWidgets(
        'should confirm the temporary account when sign-in succeeds',
        (WidgetTester tester) async {
          // Arrange
          final auth = _FakeAuthService();
          await _pumpAuth(tester, anonymous: true, authService: auth);

          // Act
          await tester.tap(find.text('SIGN IN ANONYMOUSLY'));
          await _settleAlert(tester);

          // Assert – the rendered success alert, not an internal flag.
          expect(auth.calls, ['signInAnonymously']);
          expect(
            find.text('Signed in with temporary account.'),
            findsOneWidget,
          );
          expect(find.text('Sign in failed'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'should render the disabled-provider alert when anonymous auth is off',
        (WidgetTester tester) async {
          // Arrange
          final auth = _FakeAuthService()
            ..error = FirebaseAuthException(
              code: 'operation-not-allowed',
              message: 'ignored in favor of the localized copy',
            );
          await _pumpAuth(tester, anonymous: true, authService: auth);

          // Act
          await tester.tap(find.text('SIGN IN ANONYMOUSLY'));
          await _settleAlert(tester);

          // Assert – the specific message for this code, plus the shared title.
          expect(find.text('Sign in failed'), findsOneWidget);
          expect(
            find.text('Anonymous auth hasn\'t been enabled for this project.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'should render the generic failure alert for other auth codes',
        (WidgetTester tester) async {
          // Arrange
          final auth = _FakeAuthService()
            ..error = FirebaseAuthException(code: 'network-request-failed');
          await _pumpAuth(tester, anonymous: true, authService: auth);

          // Act
          await tester.tap(find.text('SIGN IN ANONYMOUSLY'));
          await _settleAlert(tester);

          // Assert – title and body both fall back to the localized default.
          expect(find.text('Sign in failed'), findsNWidgets(2));
          expect(
            find.text('Anonymous auth hasn\'t been enabled for this project.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'should render the Firebase message for a non-auth Firebase error',
        (WidgetTester tester) async {
          // Arrange
          final auth = _FakeAuthService()
            ..error = FirebaseException(
              plugin: 'firebase_auth',
              message: 'Backend unavailable',
            );
          await _pumpAuth(tester, anonymous: true, authService: auth);

          // Act
          await tester.tap(find.text('SIGN IN ANONYMOUSLY'));
          await _settleAlert(tester);

          // Assert
          expect(find.text('Sign in failed'), findsOneWidget);
          expect(find.text('Backend unavailable'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('should stay silent when the user cancels', (
        WidgetTester tester,
      ) async {
        // Arrange
        final auth = _FakeAuthService()
          ..error = FirebaseAuthException(
            code: 'canceled',
            message: 'user closed the sheet',
          );
        await _pumpAuth(tester, anonymous: true, authService: auth);

        // Act
        await tester.tap(find.text('SIGN IN ANONYMOUSLY'));
        await _settleAlert(tester);

        // Assert – a cancellation is not a failure, so nothing is surfaced.
        expect(find.text('Sign in failed'), findsNothing);
        expect(find.text('user closed the sheet'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('phone sign-in through the injected service', () {
      testWidgets(
        'should render the failure alert when phone verification is rejected',
        (WidgetTester tester) async {
          // Arrange – section 1 with a usable number renders the verify action.
          // The page picks `signInWithPhoneNumber` on web/macOS and
          // `verifyPhoneNumber` elsewhere; both fail here so the assertion
          // holds on every host.
          final state = StateViewAuth()
            ..section = 1
            ..phone = '+15555550123';
          final auth = _FakeAuthService()
            ..error = 'phone verification rejected';
          await _pumpAuth(tester, phone: true, state: state, authService: auth);

          // Act
          await tester.tap(find.text('VERIFY'));
          await _settleAlert(tester);

          // Assert
          expect(auth.calls, hasLength(1));
          expect(
            auth.calls.single,
            anyOf('signInWithPhoneNumber', 'verifyPhoneNumber'),
          );
          expect(find.text('Sign in failed'), findsOneWidget);
          expect(find.text('phone verification rejected'), findsOneWidget);
          expect(state.section, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'should advance to the code section when verification succeeds',
        (WidgetTester tester) async {
          // Arrange
          final state = StateViewAuth()
            ..section = 1
            ..phone = '+15555550123';
          final auth = _FakeAuthService();
          await _pumpAuth(tester, phone: true, state: state, authService: auth);

          // Act
          await tester.tap(find.text('VERIFY'));
          await _settleAlert(tester);

          // Assert – no failure alert, and the flow moved on.
          expect(find.text('Sign in failed'), findsNothing);
          expect(state.section, 2);
          final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
          expect(stack.index, 2);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('should render the failure alert when the SMS code is '
          'refused', (WidgetTester tester) async {
        // Arrange – a six digit code on section 2 renders the sign-in action.
        final state = StateViewAuth()
          ..section = 2
          ..verificationId = 'verification-id'
          ..phoneVerificationCode = '123456';
        final auth = _FakeAuthService()..error = 'invalid sms code';
        await _pumpAuth(tester, phone: true, state: state, authService: auth);

        // Act
        await tester.tap(find.text('SIGN IN WITH PHONE'));
        await _settleAlert(tester);

        // Assert
        expect(auth.calls, ['signInWithPhoneCredential']);
        expect(find.text('Sign in failed'), findsOneWidget);
        expect(find.text('invalid sms code'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('unmounting mid-flight', () {
      testWidgets('should not throw when the page is disposed before the '
          'sign-in future fails', (WidgetTester tester) async {
        // Arrange – hold the seam open so the page can be torn down while the
        // call is still in flight.
        final blocker = Completer<void>();
        final auth = _FakeAuthService()
          ..pending = blocker
          ..error = 'late failure';
        final state = StateViewAuth()
          ..section = 1
          ..phone = '+15555550123';
        await _pumpAuth(tester, phone: true, state: state, authService: auth);
        await tester.tap(find.text('VERIFY'));
        await tester.pump();

        // Act – unmount the whole app, then let the pending call fail.
        await tester.pumpWidget(const SizedBox.shrink());
        blocker.complete();
        await _settleAlert(tester);

        // Assert – no setState or BuildContext use after dispose.
        expect(auth.calls, hasLength(1));
        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('should not throw when the page is disposed before an '
          'anonymous sign-in resolves', (WidgetTester tester) async {
        // Arrange
        final blocker = Completer<void>();
        final auth = _FakeAuthService()..pending = blocker;
        await _pumpAuth(tester, anonymous: true, authService: auth);
        await tester.tap(find.text('SIGN IN ANONYMOUSLY'));
        await tester.pump();

        // Act
        await tester.pumpWidget(const SizedBox.shrink());
        blocker.complete();
        await _settleAlert(tester);

        // Assert
        expect(auth.calls, ['signInAnonymously']);
        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    group('backward compatibility', () {
      testWidgets('should default to the Firebase implementation when no '
          'service is injected', (WidgetTester tester) async {
        // Arrange & Act – the historic constructor call, with no seam argument.
        await _pumpAuth(tester, anonymous: true);

        // Assert – the page still resolves a working service on its own.
        final state = tester.state<ViewAuthPageState>(
          find.byType(ViewAuthPage),
        );
        expect(state.widget.authService, isNull);
        expect(state.auth, isA<FirebaseAuthService>());
      });
    });
  });
}
