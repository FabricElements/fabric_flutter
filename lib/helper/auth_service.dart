import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'email_link_storage.dart';

/// Holds the [FirebaseAuth] singleton used by [FirebaseAuthService].
final FirebaseAuth _auth = FirebaseAuth.instance;

/// Exposes the shared [GoogleSignIn] singleton used for interactive sign-in.
///
/// Configure it once with `GoogleSignIn.initialize` (or the `index.html` meta
/// tag on web) before the app runs; this library only consumes it.
final GoogleSignIn googleSignIn = GoogleSignIn.instance;

/// Carries the Google provider used for the web popup sign-in flow.
///
/// Kept as a mutable top-level so consumers can pre-configure custom
/// parameters or scopes before the first sign-in attempt.
GoogleAuthProvider googleProvider = GoogleAuthProvider();

/// Declares the authentication operations an auth view needs.
///
/// Every method returns a plain `Future<void>` — or a `String` for the web
/// phone flow's verification id — instead of a Firebase result type. That is
/// deliberate: `UserCredential`, `User`, and `ConfirmationResult` all have
/// private constructors and cannot be built outside `firebase_auth`, so a
/// result-returning seam could never be faked. Keeping the surface primitive
/// lets a test double complete or throw at will, which is what makes the
/// failure branches of an auth view reachable.
///
/// This exists **for testability**. Production code should not implement it:
/// [FirebaseAuthService] is the real implementation and is what every widget
/// defaults to when no service is injected.
///
/// Implementations throw whatever the underlying provider throws — typically a
/// [FirebaseAuthException] carrying a `code` such as `canceled` or
/// `operation-not-allowed` — so callers can keep their existing `catch`
/// handling unchanged.
abstract class AuthService {
  /// Creates an [AuthService].
  const AuthService();

  /// Signs the user in with a throwaway anonymous account.
  ///
  /// Completes once Firebase reports the session as active. Throws a
  /// [FirebaseAuthException] with code `operation-not-allowed` when anonymous
  /// authentication is disabled for the project.
  Future<void> signInAnonymously();

  /// Signs the user in with Apple.
  ///
  /// Uses a popup on web and the native provider flow elsewhere, so callers do
  /// not branch on the platform themselves.
  Future<void> signInWithApple();

  /// Signs the user in with Google, requesting [scopes].
  ///
  /// Any previous Google session is cleared first so the account chooser is
  /// always shown. Uses a popup on web and the interactive `authenticate`
  /// flow elsewhere.
  Future<void> signInWithGoogle({required List<String> scopes});

  /// Starts the web/macOS phone flow for [phoneNumber] and returns its
  /// verification id.
  ///
  /// The pending confirmation is retained by the implementation so
  /// [confirmPhoneCode] can complete the flow without the caller holding a
  /// `ConfirmationResult`.
  Future<String> signInWithPhoneNumber(String phoneNumber);

  /// Starts the native phone verification flow for [phoneNumber].
  ///
  /// The four callbacks mirror `FirebaseAuth.verifyPhoneNumber`:
  /// [verificationCompleted] fires when the code is auto-resolved,
  /// [verificationFailed] when verification is rejected, [codeSent] once the
  /// SMS is dispatched, and [codeAutoRetrievalTimeout] when auto-retrieval
  /// expires.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  });

  /// Completes the web phone flow with the SMS [smsCode].
  ///
  /// Requires a prior [signInWithPhoneNumber] call; implementations throw when
  /// no confirmation is pending.
  Future<void> confirmPhoneCode(String smsCode);

  /// Signs the user in with the phone credential built from [verificationId]
  /// and [smsCode].
  ///
  /// This is the native counterpart of [confirmPhoneCode].
  Future<void> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  });

  /// Signs the user in with an already-resolved [credential].
  ///
  /// Used by the auto-resolved phone flow, where Firebase hands back a
  /// credential instead of an SMS code.
  Future<void> signInWithCredential(AuthCredential credential);

  /// Sends a passwordless sign-in link to [email].
  ///
  /// [url] is the continue URL the link redirects back to once it is opened,
  /// which is what returns the user to the page they started from. It is
  /// required because Firebase needs somewhere to send the browser, and it must
  /// be under an authorized domain for the project.
  ///
  /// [iOSBundleId] and [androidPackageName] route an opened link to the native
  /// app instead of the browser; [androidInstallApp] additionally lets Firebase
  /// send users without the app to the Play Store. [linkDomain] is the custom
  /// Firebase Hosting domain used for the link, required when the project does
  /// not use a default `*.web.app` / `*.firebaseapp.com` domain.
  ///
  /// No password is created or reset: opening the link is the only way to
  /// complete this flow. Throws a [FirebaseAuthException] with code
  /// `invalid-email` when the address is rejected.
  Future<void> sendSignInLinkToEmail({
    required String email,
    required String url,
    String? iOSBundleId,
    String? androidPackageName,
    bool androidInstallApp = false,
    String? linkDomain,
  });

  /// Returns whether [link] is a sign-in link this project issued.
  ///
  /// Callers should check this before [signInWithEmailLink] so an ordinary URL
  /// opened through the same app-links mechanism is not mistaken for a
  /// credential.
  bool isSignInWithEmailLink(String link);

  /// Completes a passwordless sign-in from the [link] sent to [email].
  ///
  /// [email] must be the address the link was sent to. Throws a
  /// [FirebaseAuthException] with code `expired-action-code` for a link that is
  /// no longer valid, `invalid-email` when the address does not match the link,
  /// or `user-disabled` when the account has been disabled.
  Future<void> signInWithEmailLink({
    required String email,
    required String link,
  });

  /// Completes a passwordless sign-in from an already-opened [link].
  ///
  /// A convenience entry point for hosts that receive the incoming link
  /// themselves — on Android and iOS the app has to hand the link to the
  /// package, because there is no ambient URL to read. Does nothing when [link]
  /// is not a sign-in link, which makes it safe to call for every incoming app
  /// link. Always clears the remembered address once it succeeds.
  Future<void> completeEmailLinkSignIn(String link);
}

/// Performs authentication against Firebase and Google Sign-In.
///
/// This is the default [AuthService] used whenever a widget is constructed
/// without an explicit service, so existing call sites keep talking to the
/// real backend. Instances are cheap and hold only the pending web phone
/// confirmation between [signInWithPhoneNumber] and [confirmPhoneCode].
class FirebaseAuthService extends AuthService {
  /// Creates a [FirebaseAuthService] bound to the default Firebase app.
  FirebaseAuthService();

  /// Retains the pending web phone confirmation between the verify and confirm
  /// steps.
  ConfirmationResult? _confirmationResult;

  /// Asserts that the signed-in [user] matches `FirebaseAuth.currentUser`.
  ///
  /// The check only runs in debug builds and guards against a credential being
  /// applied to a different session than the one the app observes.
  void _assertCurrentUser(User? user) {
    assert(user != null, 'Sign in did not return a user');
    assert(
      user!.uid == _auth.currentUser?.uid,
      'Signed in user does not match the current user',
    );
  }

  @override
  Future<void> signInAnonymously() async {
    final userCredential = await _auth.signInAnonymously();
    _assertCurrentUser(userCredential.user);
  }

  @override
  Future<void> signInWithApple() async {
    final appleProvider = AppleAuthProvider();
    // This scope is required to receive the account email.
    appleProvider.addScope('email');
    if (kIsWeb) {
      await _auth.signInWithPopup(appleProvider);
    } else {
      await _auth.signInWithProvider(appleProvider);
    }
  }

  @override
  Future<void> signInWithGoogle({required List<String> scopes}) async {
    try {
      // The singleton API exposes no `currentUser` getter, so always attempt a
      // sign out first to guarantee a fresh interactive sign-in.
      await googleSignIn.signOut();
    } catch (error) {
      // Ignore sign out errors: there may simply be no active session.
    }
    if (kIsWeb) {
      for (final scope in scopes) {
        googleProvider.addScope(scope);
      }
      await _auth.signInWithPopup(googleProvider);
      return;
    }
    final authenticated = await googleSignIn.authenticate(scopeHint: scopes);
    // `authenticate` returns a non-null account on success or throws, so no
    // null check is necessary here.
    final GoogleSignInAuthentication googleAuth = authenticated.authentication;
    // Prefer the authorization client's access token but fall back to the
    // authentication object's id token: some platforms only return one of the
    // two, and Firebase accepts either.
    final clientAuth = await authenticated.authorizationClient
        .authorizationForScopes(scopes);
    final String? accessToken = clientAuth?.accessToken;
    final String? idToken = googleAuth.idToken;
    assert(
      accessToken != null || idToken != null,
      'At least one of ID token and access token is required',
    );
    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<String> signInWithPhoneNumber(String phoneNumber) async {
    final confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
    _confirmationResult = confirmationResult;
    return confirmationResult.verificationId;
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      forceResendingToken: 3,
      phoneNumber: phoneNumber,
      timeout: const Duration(minutes: 2),
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  @override
  Future<void> confirmPhoneCode(String smsCode) async {
    assert(
      _confirmationResult?.verificationId != null,
      'Please input sms code received after verifying phone number',
    );
    final credential = await _confirmationResult!.confirm(smsCode);
    _assertCurrentUser(credential.user);
  }

  @override
  Future<void> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    final AuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    _assertCurrentUser(userCredential.user);
  }

  @override
  Future<void> signInWithCredential(AuthCredential credential) async {
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> sendSignInLinkToEmail({
    required String email,
    required String url,
    String? iOSBundleId,
    String? androidPackageName,
    bool androidInstallApp = false,
    String? linkDomain,
  }) async {
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: url,
        // Required by `sendSignInLinkToEmail`, which throws an `ArgumentError`
        // without it: the link must be handled by the app so the signed-in
        // session lands in this app rather than a browser tab.
        handleCodeInApp: true,
        iOSBundleId: iOSBundleId,
        androidPackageName: androidPackageName,
        androidInstallApp: androidInstallApp,
        linkDomain: linkDomain,
      ),
    );
  }

  @override
  bool isSignInWithEmailLink(String link) => _auth.isSignInWithEmailLink(link);

  @override
  Future<void> signInWithEmailLink({
    required String email,
    required String link,
  }) async {
    final userCredential = await _auth.signInWithEmailLink(
      email: email,
      emailLink: link,
    );
    _assertCurrentUser(userCredential.user);
  }

  @override
  Future<void> completeEmailLinkSignIn(String link) async {
    if (!isSignInWithEmailLink(link)) return;
    final email = EmailLinkStorage.read();
    if (email == null || email.isEmpty) {
      throw StateError(
        'No email address is stored for this sign-in link. The host app must '
        'ask the user for the address the link was sent to.',
      );
    }
    await signInWithEmailLink(email: email, link: link);
    EmailLinkStorage.clear();
  }
}
