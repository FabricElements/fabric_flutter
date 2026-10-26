import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../component/alert_data.dart';
import '../component/content_container.dart';
import '../component/input_data.dart';
import '../component/phone_input.dart';
import '../component/smart_image.dart';
import '../helper/agent/agent_element_binding.dart';
import '../helper/announce.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/auth_service.dart';
import '../helper/density_spacing.dart';
import '../helper/email_link_storage.dart';
import '../helper/input_validation.dart';
import '../helper/log_color.dart';
import '../helper/url_safety.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/agent_element_snapshot.dart';
import '../state/state_analytics.dart';
import '../state/state_global.dart';
import '../state/state_view_auth.dart';

/// Re-exports the authentication seam so importers of this view keep access to
/// [AuthService], [FirebaseAuthService], `googleSignIn`, and `googleProvider`,
/// which used to be declared here.
export '../helper/auth_service.dart';

/// One legal document offered on the authentication page.
///
/// A consumer supplies these through [ViewAuthPage.legalLinks] so the page can
/// render a consent sentence that links to the terms and privacy documents it
/// hosts itself. The page never bundles or fetches the documents: it only opens
/// [url] in the platform browser, so the text stays under the consumer's
/// control and can be updated without shipping a new build.
class ViewAuthLegalLink {
  /// Creates a legal link labelled [label] that opens [url].
  const ViewAuthLegalLink({required this.label, required this.url});

  /// The visible, already-localized name of the document.
  ///
  /// Shown inside the consent sentence and used as the accessible name of the
  /// link, so it should read as a noun phrase ("Terms of Service").
  final String label;

  /// The absolute address of the document.
  ///
  /// Only `http` and `https` URLs are launched; see [UrlSafety]. A link with
  /// any other scheme renders but does nothing when tapped.
  final Uri url;
}

/// Provides a full-screen authentication page with multiple sign-in options.
///
/// [ViewAuthPage] supports phone number authentication, Google Sign-In, Apple
/// Sign-In, and anonymous authentication. The page displays a configurable logo,
/// title, description, and background image, along with an optional consent
/// sentence linking to the consumer's own legal documents.
class ViewAuthPage extends StatefulWidget {
  const ViewAuthPage({
    super.key,
    this.loader,
    this.image,
    this.phone = false,
    this.email = false,
    this.google = false,
    this.apple = false,
    this.anonymous = false,
    this.googleClientId,
    this.androidPackageName,
    this.iOSBundleId,
    this.emailLinkDomain,
    this.emailLinkAndroidInstallApp = false,
    this.legalLinks,
    required this.url,
    this.logo,
    this.logoHeight = 150,
    this.logoWidth = 150,
    this.logoCircle = false,
    this.logoSemanticLabel,
    this.title,
    this.description,
    this.authService,
  });

  final Widget? loader;
  final String? image;
  final bool phone;

  /// Whether to offer passwordless sign-in by email link.
  ///
  /// Defaults to `false`, so an existing call site renders exactly what it did
  /// before. When enabled the page shows an email option next to the other
  /// providers; the user enters an address, receives a link, and is signed in
  /// by opening it. **No password is ever set, reset, or stored**, and the page
  /// renders no sign-up form, so a project that only enables the Email link
  /// provider stays passwordless.
  ///
  /// Completing the link needs a continue URL, which by default is [url].
  final bool email;

  final bool google;
  final bool apple;
  final bool anonymous;

  /// Holds a legacy Google Sign-In client id that is no longer read.
  ///
  /// The value is ignored: the client id is now configured globally instead of
  /// per widget. On index.html for web, set the client ID in the meta tag and
  /// the script tag:
  /// <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
  /// <script async defer src="https://accounts.google.com/gsi/client"></script>
  ///
  /// Use [GoogleSignIn.initialize] before running the app on main()
  /// final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  ///
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   try {
  ///     // initialize returns a Future; we don't need to await it here.
  ///     await googleSignIn.initialize(
  ///       clientId: kIsWeb ? EnvironmentConfig.GOOGLE_SIGNIN_CLIENT_ID : null,
  ///     );
  ///   } catch (e) {
  ///     debugPrint("Google Init Error: $e");
  ///   }
  ///  ...
  ///
  @Deprecated(
    'The Google Sign-In client id is now configured globally with '
    'GoogleSignIn.initialize (or the index.html meta tag on web) and this '
    'value is ignored. Remove the argument; it will be deleted in a future '
    'release.',
  )
  final String? googleClientId;

  /// The Android package name of the application to open when the URL is pressed.
  final String? androidPackageName;

  /// The iOS app to open if it is installed on the device.
  final String? iOSBundleId;

  /// Custom Firebase Hosting domain used for the sign-in link.
  ///
  /// Maps onto `ActionCodeSettings.linkDomain` and is only needed when the
  /// project does not use a default `*.web.app` / `*.firebaseapp.com` domain.
  /// A consumer that serves the app from its own host (for example
  /// `app.example.com`) sets this so the link is issued from the domain the
  /// user already trusts.
  final String? emailLinkDomain;

  /// Whether to send users without the app to the Play Store.
  ///
  /// Maps onto `ActionCodeSettings.androidInstallApp`. Defaults to `false`,
  /// matching Firebase, so an opened link only opens the app when it is
  /// already installed.
  final bool emailLinkAndroidInstallApp;

  /// Sets the link continue/state URL
  final String url;

  /// Legal documents shown as a consent sentence below the sign-in options.
  ///
  /// When `null` or empty nothing is rendered, so a consumer that has no
  /// published documents keeps the previous layout. When non-empty the page
  /// renders a localized "By continuing, you agree to our …" line whose links
  /// open [ViewAuthLegalLink.url] in the platform browser. Each link is
  /// published to assistive technology and to the agent bridge as
  /// `auth_legal_link_<index>`, in list order.
  ///
  /// This replaces the former `policies` asset path, which loaded a bundled
  /// markdown file into an accept/reject dialog. The documents now live on the
  /// consumer's own site, so they can change without a new build and the page
  /// no longer gates sign-in on a dialog.
  final List<ViewAuthLegalLink>? legalLinks;

  final String? logo;
  final double logoHeight;
  final double logoWidth;
  final bool logoCircle;

  /// Optional accessible name announced for [logo] by assistive technology.
  ///
  /// When `null`, the logo falls back to [SmartImage]'s default image label so
  /// screen readers still describe the brand mark rather than skipping it.
  final String? logoSemanticLabel;
  final String? title;
  final String? description;

  /// Overrides the authentication backend used by every sign-in button.
  ///
  /// Exists **for testability**. When `null` — the default, and what every
  /// production call site should keep using — the page builds a
  /// [FirebaseAuthService] and talks to Firebase and Google Sign-In exactly as
  /// before. Supplying a fake [AuthService] lets a test complete or throw at
  /// will and therefore exercise the failure branches, which are otherwise
  /// unreachable because the mocked Firebase method channel never completes.
  final AuthService? authService;

  @override
  State<ViewAuthPage> createState() => ViewAuthPageState();
}

class ViewAuthPageState extends State<ViewAuthPage> {
  late bool loading;

  /// Identifies the asynchronous link check kicked off in [initState].
  ///
  /// Held so [dispose] can ignore it: a web page can be torn down while the
  /// link is still being redeemed, and touching the state object afterwards
  /// would be a use-after-dispose.
  int _linkCheckToken = 0;

  /// Whether this element has been disposed.
  bool _disposed = false;

  /// Performs the actual sign-in calls for this page.
  ///
  /// Resolved once so a page-scoped [FirebaseAuthService] can retain the
  /// pending web phone confirmation across the verify/confirm steps, mirroring
  /// how that confirmation used to be held by this state object.
  late final AuthService auth;

  /// Holds the pending web phone confirmation.
  ///
  /// No longer populated: the confirmation is retained by [auth] so the page
  /// never handles a `ConfirmationResult` it cannot fake in a test. Kept only
  /// so existing references still compile.
  @Deprecated(
    'The pending confirmation is now held by AuthService and this field is '
    'always null. It will be removed in a future release.',
  )
  ConfirmationResult? webConfirmationResult;
  final List<String> googleScopes = <String>['openid', 'email'];
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    loading = false;
    auth = widget.authService ?? FirebaseAuthService();
    if (widget.email) {
      // The provider tree is not readable until the first build, so the
      // incoming-link check has to wait for one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleIncomingEmailLink();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _linkCheckToken++;
    super.dispose();
  }

  /// Resolves the continue URL the sign-in link should return to.
  ///
  /// [ViewAuthPage.url] wins because a host that renders this page at a fixed
  /// route knows where the user was; otherwise the environment is asked, which
  /// on web means the full current address including path and query. Returns
  /// `null` when neither is usable, and the caller then skips the request
  /// rather than sending a link Firebase would reject.
  String? _resolveEmailLinkUrl() {
    if (widget.url.isNotEmpty) return widget.url;
    final location = EmailLinkStorage.currentLocation();
    return location == null || location.isEmpty ? null : location;
  }

  /// Reads the ambient URL and attempts to complete a sign-in link from it.
  ///
  /// Runs once per element because the incoming link is only ever on the URL the
  /// browser loaded with. Several platforms hand the link to the app instead of
  /// the page, so this only covers web; a host on mobile passes the link to
  /// [completeEmailLinkSignIn] itself.
  ///
  /// Completing and cleaning the address happen in this order on purpose: the
  /// `oobCode` is single-use, so it is redeemed before the URL is rewritten, and
  /// the address is only touched after the attempt resolves.
  Future<void> _handleIncomingEmailLink() async {
    if (_disposed || !mounted) return;
    final token = ++_linkCheckToken;
    final state = Provider.of<StateViewAuth>(context, listen: false);
    final location = EmailLinkStorage.currentLocation();
    if (location == null || location.isEmpty) return;
    if (!auth.isSignInWithEmailLink(location)) return;
    state.returnUrl = location;
    final stored = EmailLinkStorage.read();
    if (stored == null || stored.isEmpty) {
      // Opened on a device that never requested the link, so the address has to
      // come from the user before Firebase can match it to the code.
      state.email = null;
      state.awaitingEmailForLink = true;
      state.section = 4;
      if (mounted) setState(() {});
      return;
    }
    state.email = stored;
    await _completeEmailLink(location, stored);
    if (_linkCheckSuperseded(token)) return;
    EmailLinkStorage.clearLinkFromLocation();
  }

  /// Whether the element is gone or a newer link check has superseded [token].
  ///
  /// Checked after the awaited redemption so a page torn down mid-flight never
  /// touches [State] or the address bar.
  bool _linkCheckSuperseded(int token) =>
      _disposed || !mounted || token != _linkCheckToken || !context.mounted;

  /// Presents a localized sign-in failure alert and announces it.
  ///
  /// Every caller reaches this from a `catch` block that follows an awaited
  /// authentication call, so the element backing this view may already have been
  /// unmounted. No context is passed to `alertData`, which resolves the root
  /// context itself, so the failure is always surfaced. The announcement is
  /// skipped when this element is gone, because `announce` needs its live view.
  void _alertEmailFailure(String? body) {
    final heading = AppLocalizations.of(context).get('alert--sign-in-failed');
    alertData(title: heading, body: body, type: AlertType.critical);
    if (mounted) announce(context, heading);
  }

  /// Sends a passwordless sign-in link to [email] that returns the user to [url].
  ///
  /// The only email entry point: no password is ever collected, set, or reset,
  /// and no account is created by this call. Firestore security rules and a
  /// `beforeSignIn` blocking function remain the real gate, because a client
  /// cannot stop a determined caller from also using the password provider.
  ///
  /// The address is remembered locally so the same device can finish without
  /// retyping it; a device that never requested the link is prompted instead.
  Future<void> _sendEmailLink({
    required String email,
    required String url,
  }) async {
    final locales = AppLocalizations.of(context);
    final state = Provider.of<StateViewAuth>(context, listen: false);
    try {
      state.returnUrl = url;
      loading = true;
      if (mounted) setState(() {});
      await auth.sendSignInLinkToEmail(
        email: email,
        url: url,
        iOSBundleId: widget.iOSBundleId,
        androidPackageName: widget.androidPackageName,
        androidInstallApp: widget.emailLinkAndroidInstallApp,
        linkDomain: widget.emailLinkDomain,
      );
      EmailLinkStorage.write(email);
      state.emailLinkSent = true;
      state.lastEmailLinkSentAt = DateTime.now();
      state.section = 4;
      final sent = locales.get('alert--email-link-sent');
      alertData(title: sent, type: AlertType.success);
      if (mounted) announce(context, sent);
    } on FirebaseAuthException catch (error) {
      _alertEmailFailure(
        error.code == 'invalid-email'
            ? locales.get('alert--invalid-email')
            : error.message ?? locales.get('alert--sign-in-failed'),
      );
    } on FirebaseException catch (error) {
      _alertEmailFailure(error.message);
    } catch (error) {
      _alertEmailFailure(error.toString());
    } finally {
      loading = false;
      if (mounted) setState(() {});
    }
  }

  /// Redeems an email sign-in link and finishes the shared post-auth path.
  ///
  /// Shared by the incoming-link check, the host entry point, and the
  /// hand-typed address step. The remembered address is cleared only on
  /// success, because the link code is single-use: discarding it after a
  /// failure would strand a retry.
  Future<void> _completeEmailLink(String link, String email) async {
    final locales = AppLocalizations.of(context);
    final state = Provider.of<StateViewAuth>(context, listen: false);
    try {
      loading = true;
      if (mounted) setState(() {});
      await auth.signInWithEmailLink(email: email, link: link);
      EmailLinkStorage.clear();
      state.emailLinkSent = false;
      state.awaitingEmailForLink = false;
      alertData(
        title: locales.get('alert--email-link-sent'),
        type: AlertType.success,
      );
    } on FirebaseAuthException catch (error) {
      String message;
      switch (error.code) {
        case 'expired-action-code':
        case 'invalid-action-code':
          message = locales.get('alert--email-link-invalid');
          break;
        case 'invalid-email':
          message = locales.get('alert--email-link-email-mismatch');
          break;
        default:
          message = error.message ?? locales.get('alert--sign-in-failed');
      }
      _alertEmailFailure(message);
    } on FirebaseException catch (error) {
      _alertEmailFailure(error.message);
    } catch (error) {
      _alertEmailFailure(error.toString());
    } finally {
      loading = false;
      if (mounted) setState(() {});
    }
  }

  /// Completes a passwordless email-link sign-in from a link the host received.
  ///
  /// The host-facing entry point for platforms that hand the link to the app
  /// rather than to a page: a deep link, a universal-link handler, or an
  /// `app_links` stream. Call it with the incoming link and this page finishes
  /// the sign-in, including the "which address was this sent to?" step when the
  /// link is opened on a device that never requested it.
  ///
  /// Does nothing when [link] is not a Firebase email sign-in link, so a host
  /// may forward every inbound link without filtering first.
  Future<void> completeEmailLinkSignIn(String link) async {
    if (!auth.isSignInWithEmailLink(link)) return;
    final state = Provider.of<StateViewAuth>(context, listen: false);
    state.returnUrl ??= link;
    final stored = EmailLinkStorage.read();
    if (stored != null && stored.isNotEmpty) {
      state.email = stored;
      await _completeEmailLink(link, stored);
      return;
    }
    // Opened on a device that never requested the link, so the address has to
    // come from the user before Firebase can match it to the code.
    state.email = null;
    state.awaitingEmailForLink = true;
    state.section = 4;
    if (mounted) setState(() {});
    if (mounted) {
      announce(
        context,
        AppLocalizations.of(context).get('page-auth--email-link-missing-email'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateGlobal = Provider.of<StateGlobal>(context);
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);
    final state = Provider.of<StateViewAuth>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locales = AppLocalizations.of(context);
    final textTheme = theme.textTheme;
    final density = DensitySpacing(theme.visualDensity);
    stateAnalytics.screenName = 'auth';
    // Initialize after first build
    if (!initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        initialized = true;
        if (mounted) setState(() {});
      });
    }
    bool connected = stateGlobal.connected;
    if (loading || !initialized || !connected) {
      return widget.loader ?? const LoadingScreen();
    }

    /// Announces a message to assistive technology such as screen readers.
    ///
    /// Used for auth failures and step transitions so users relying on
    /// TalkBack/VoiceOver are notified even though those changes are only
    /// visual (an [AnimatedOpacity]/[IndexedStack] swap) by default.
    ///
    /// Several callers run after an awaited Firebase call, so the guard lives
    /// in [announce]: unlike [alertData], an announcement needs this element's
    /// live view and cannot fall back to a root context.
    void announceMessage(String message) {
      announce(context, message);
    }

    /// Reset view to initial state
    Future<void> resetView() async {
      // Callers reach this from `catch`/`finally` blocks that follow awaited
      // Firebase calls, so the view may already be gone.
      if (!context.mounted) return;
      loading = true;
      // Close Keyboard
      FocusScope.of(context).unfocus();
      state.clear();
      await Future.delayed(const Duration(seconds: 1));
      loading = false;
      if (mounted) setState(() {});
      announceMessage(widget.title ?? locales.get('page-auth--title'));
    }

    /// Presents a localized sign-in failure alert.
    ///
    /// Every caller reaches this from a `catch` block that follows an awaited
    /// authentication call, so the element backing this view may already have
    /// been unmounted. No context is passed: [alertData] resolves the root
    /// context itself, so the failure is always surfaced. The optional [title]
    /// overrides the default `alert--sign-in-failed` heading.
    ///
    /// The failure is also announced through the semantics tree so screen
    /// reader users learn about it: the alert is a transient overlay that does
    /// not otherwise move focus.
    void alertSignInFailed(String? body, {String? title}) {
      final heading = title ?? locales.get('alert--sign-in-failed');
      alertData(title: heading, body: body, type: AlertType.critical);
      announceMessage(heading);
    }

    /// Verification completed: Sign in with credentials
    verificationCompleted(AuthCredential phoneAuthCredential) async {
      await auth.signInWithCredential(phoneAuthCredential);
      alertData(body: locales.get('alert--received-phone-auth-credential'));
    }

    /// Verification Failed
    verificationFailed(FirebaseAuthException error) {
      bool authCanceled = error.code == 'canceled';
      if (authCanceled) {
        debugPrint(LogColor.error(error.message ?? error.code));
        return;
      }
      final message =
          '${locales.get('alert--phone-number-verification-failed')}. ${error.message} -- Code: ${error.code}';
      alertData(context: context, body: message, type: AlertType.critical);
      announceMessage(message);
    }

    /// SMS auth code sent
    codeSent(String verificationId, [int? forceResendingToken]) {
      loading = true;
      if (mounted) setState(() {});
      alertData(
        context: context,
        body: locales.get('alert--check-phone-verification-code'),
        type: AlertType.success,
        duration: 3,
      );
      state.verificationId = verificationId;
      state.section = 2;
      loading = false;
      if (mounted) setState(() {});
      announceMessage(locales.get('page-auth--input--verification-code'));
    }

    /// SMS auth code retrieval timeout
    codeAutoRetrievalTimeout(String verificationId) {
      state.verificationId = verificationId;
    }

    /// Verify phone number
    void verifyPhoneNumber() async {
      assert(state.phoneValid != null, 'Phone number can\'t be null');
      loading = true;
      bool success = false;
      if (mounted) setState(() {});
      try {
        if (kIsWeb || Platform.isMacOS) {
          state.verificationId = await auth.signInWithPhoneNumber(
            state.phoneValid!,
          );
        } else {
          await auth.verifyPhoneNumber(
            phoneNumber: state.phoneValid!,
            verificationCompleted: verificationCompleted,
            verificationFailed: verificationFailed,
            codeSent: codeSent,
            codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
          );
        }
        success = true;
      } catch (error) {
        debugPrint(LogColor.error('ConfirmationResult Error: $error'));
        alertSignInFailed(error.toString());
      }
      loading = false;
      if (success) {
        state.section = 2;
      }
      if (mounted) setState(() {});
    }

    Future<void> confirmCodeWeb() async {
      loading = true;
      if (mounted) setState(() {});
      try {
        assert(
          state.phoneVerificationCode != null &&
              state.phoneVerificationCode!.length == 6,
          'Enter valid confirmation code',
        );
        await auth.confirmPhoneCode(state.phoneVerificationCode!);
        await Future.delayed(const Duration(seconds: 3));
        resetView();
      } catch (error) {
        alertSignInFailed(error.toString());
      } finally {
        loading = false;
        if (mounted) setState(() {});
      }
    }

    /// Example code of how to sign in with phone.
    void signInWithPhoneNumber() async {
      loading = true;
      if (mounted) setState(() {});
      try {
        assert(state.verificationId != null, 'VerificationId missing');
        assert(
          state.phoneVerificationCode != null &&
              state.phoneVerificationCode!.length == 6,
          'Enter valid confirmation code',
        );
        await auth.signInWithPhoneCredential(
          verificationId: state.verificationId!,
          smsCode: state.phoneVerificationCode!,
        );
        await Future.delayed(const Duration(seconds: 3));
        resetView();
      } catch (error) {
        alertSignInFailed(error.toString());
      } finally {
        loading = false;
        if (mounted) setState(() {});
      }
    }

    /// Sign in with google function
    signInGoogle() async {
      // loading = true;
      // if (mounted) setState(() {});
      try {
        await auth.signInWithGoogle(scopes: googleScopes);
      } on FirebaseAuthException catch (error) {
        bool authCanceled = error.code == 'canceled';
        if (!authCanceled) {
          alertSignInFailed(error.message);
        }
      } on FirebaseException catch (error) {
        alertSignInFailed(error.message);
      } catch (error) {
        alertSignInFailed(error.toString());
      }
      loading = false;
      if (mounted) setState(() {});
    }

    /// Sign in anonymously
    signInAnonymously() async {
      try {
        await auth.signInAnonymously();
        alertData(
          title: 'Signed in with temporary account.',
          type: AlertType.success,
        );
      } on FirebaseAuthException catch (e) {
        debugPrint(LogColor.error(e));
        String errorMessage = locales.get('alert--sign-in-failed');
        switch (e.code) {
          case 'operation-not-allowed':
            errorMessage =
                'Anonymous auth hasn\'t been enabled for this project.';
            break;
        }
        bool authCanceled = e.code == 'canceled';
        if (!authCanceled) {
          alertSignInFailed(errorMessage);
        }
      } on FirebaseException catch (error) {
        alertSignInFailed(error.message);
      }
    }

    /// Sign in with Apple
    signInWithApple() async {
      try {
        loading = true;
        if (mounted) setState(() {});
        await auth.signInWithApple();
      } on FirebaseAuthException catch (error) {
        bool authCanceled = error.code == 'canceled';
        if (!authCanceled) {
          alertSignInFailed(error.message);
        }
      } on FirebaseException catch (error) {
        alertSignInFailed(error.message);
      } catch (error) {
        alertSignInFailed(
          error.toString(),
          title: locales.get('alert--sign-in-failed: '),
        );
        announceMessage(locales.get('alert--sign-in-failed'));
      } finally {
        resetView();
      }
    }

    /// Sends the sign-in link to the address currently in the view state.
    ///
    /// Resolves the continue URL first so a host that configured none fails
    /// loudly instead of asking Firebase for a link it would reject.
    sendEmailLink() async {
      final url = _resolveEmailLinkUrl();
      if (url == null) {
        alertSignInFailed(locales.get('alert--email-link-url-missing'));
        return;
      }
      final email = state.email;
      if (email == null || email.isEmpty) {
        alertSignInFailed(locales.get('alert--email-link-missing'));
        return;
      }
      await _sendEmailLink(email: email, url: url);
    }

    /// Resends the link, respecting a 30 second cooldown.
    ///
    /// The wait is announced rather than silently swallowed so a repeated tap
    /// is explained instead of looking broken.
    resendEmailLink() async {
      final last = state.lastEmailLinkSentAt;
      final waited = last == null ? null : DateTime.now().difference(last);
      if (waited != null && waited < const Duration(seconds: 30)) {
        final remaining = 30 - waited.inSeconds.clamp(0, 30);
        announceMessage(
          locales.get('label--email-link-cooldown', {'seconds': '$remaining'}),
        );
        return;
      }
      await sendEmailLink();
    }

    /// Finishes a link whose address had to be supplied by hand.
    ///
    /// Used when the user opened the link on a device that never requested it,
    /// so no address was remembered locally.
    confirmEmailLink() async {
      final link = state.returnUrl;
      final email = state.email;
      if (link == null || email == null || email.isEmpty) return;
      await _completeEmailLink(link, email);
    }

    /// Returns to the email step without clearing the address.
    ///
    /// Keeping the address pre-fills the field, since the common reason to go
    /// back is a typo rather than a different account.
    changeEmail() {
      state.emailLinkSent = false;
      state.awaitingEmailForLink = false;
      state.section = 3;
      if (mounted) setState(() {});
      announceMessage(locales.get('page-auth--email--input'));
    }

    /// Acton button for general use
    Widget actionButton({
      label = String,
      onPressed = VoidCallback,
      icon = Icons.navigate_next,
      String? automationKey,
      String? semanticHint,
    }) {
      final button = SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
      if (automationKey == null) return button;
      return AgentElement(
        id: automationKey,
        type: AgentElementType.button,
        label: label,
        hint: semanticHint,
        enabledGetter: () => onPressed != null,
        activator: () async => onPressed(),
        child: button,
      );
    }

    /// Auth button widget
    Widget authButton(provider) {
      String text = locales.get('label--sign-in');
      var icon = Icons.email;
      Function action = () {
        debugPrint(LogColor.info('clicked: $provider'));
      };
      //      Color _iconColor = Material;
      switch (provider) {
        case 'anonymous':
          text = locales.get('label--sign-in-anonymously');
          icon = Icons.shield;
          action = signInAnonymously;
          break;
        case 'apple':
          text = locales.get('label--sign-in-apple');
          icon = Icons.apple;
          action = signInWithApple;
          break;
        case 'phone':
          icon = Icons.phone;
          text = locales.get('label--not-supported');
          text = locales.get('label--sign-in-mobile');
          action = () {
            state.section = 1;
            if (mounted) setState(() {});
            announceMessage(locales.get('label--phone-number'));
          };
          break;
        case 'google':
          text = locales.get('label--sign-in-google');
          icon = Icons.link;
          action = signInGoogle;
          break;
        case 'email':
          text = locales.get('label--sign-in-email');
          icon = Icons.email;
          action = () {
            state.section = 3;
            if (mounted) setState(() {});
            announceMessage(locales.get('page-auth--email--input'));
          };
          break;
      }
      return Padding(
        padding: density.only(top: 16, minVertical: 8),
        child: AgentElement(
          id: 'auth_home_button_$provider',
          type: AgentElementType.button,
          label: text,
          hint: locales.get('label--sign-in'),
          activator: () async => action(),
          child: FilledButton.icon(
            onPressed: () => action(),
            label: Text(text.toUpperCase()),
            icon: Icon(icon),
          ),
        ),
      );
    }

    /// Builds the consent sentence that links to the consumer's legal pages.
    ///
    /// Returns `null` when [ViewAuthPage.legalLinks] is null or empty so the
    /// caller can omit the line entirely. The sentence is one [Text.rich] so it
    /// wraps as a single paragraph, and each link is its own [AgentElement] and
    /// [Semantics] node: an agent or screen reader reaches the documents
    /// individually instead of hearing one undifferentiated sentence.
    ///
    /// Links are joined the way a person writes a list — `", "` between items
    /// and a localized conjunction before the last one — so the sentence reads
    /// naturally in both bundled languages.
    Widget? legalConsentLine() {
      final links = widget.legalLinks;
      if (links == null || links.isEmpty) return null;
      // The sentence is a localized template with a `{links}` placeholder, so
      // the surrounding wording and word order stay in the locale file instead
      // of being assembled from fragments here.
      final template = locales.get('page-auth--legal-consent');
      final placeholder = template.indexOf('{links}');
      final prefix = placeholder < 0
          ? template
          : template.substring(0, placeholder);
      final suffix = placeholder < 0
          ? ''
          : template.substring(placeholder + '{links}'.length);
      final conjunction = locales.get('page-auth--legal-consent-and');
      final linkStyle = textTheme.bodySmall?.copyWith(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: colorScheme.primary,
      );
      final spans = <InlineSpan>[];
      for (var index = 0; index < links.length; index++) {
        final link = links[index];
        if (index > 0) {
          final isLast = index == links.length - 1;
          spans.add(TextSpan(text: isLast ? ' $conjunction ' : ', '));
        }
        Future<void> open() => UrlSafety.launch(
          link.url.toString(),
          mode: LaunchMode.externalApplication,
        );
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: AgentElement(
              id: 'auth_legal_link_$index',
              type: AgentElementType.navigation,
              label: link.label,
              activator: open,
              child: Semantics(
                link: true,
                label: link.label,
                onTap: open,
                child: InkWell(
                  onTap: open,
                  child: Text(link.label, style: linkStyle),
                ),
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: density.only(top: 16, minVertical: 8),
        child: Text.rich(
          TextSpan(
            text: prefix,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            children: [
              ...spans,
              if (suffix.isNotEmpty) TextSpan(text: suffix),
            ],
          ),
        ),
      );
    }

    final legalConsent = legalConsentLine();

    String backgroundImage =
        widget.image ??
        'https://images.unsplash.com/photo-1615406020658-6c4b805f1f30';
    Widget spacer = SizedBox(width: density.gap(8), height: density.gap(8));
    Widget spacerLarge = SizedBox(
      width: density.gap(16),
      height: density.gap(16),
    );
    List<Widget> homeButtonOptions = [];
    if (widget.apple && !kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      homeButtonOptions.add(authButton('apple'));
    }
    if (widget.google && (kIsWeb || Platform.isIOS || Platform.isAndroid)) {
      homeButtonOptions.add(authButton('google'));
    }
    if (widget.phone && (kIsWeb || Platform.isIOS || Platform.isAndroid)) {
      homeButtonOptions.add(authButton('phone'));
    }
    if (widget.anonymous) homeButtonOptions.add(authButton('anonymous'));
    if (widget.email) homeButtonOptions.add(authButton('email'));
    Widget? logoImage = widget.logo != null
        ? SmartImage(
            key: ValueKey('auth-page-logo-circle-${widget.logo}'),
            url: widget.logo,
            format: AvailableOutputFormats.png,
            color: theme.colorScheme.surface,
            semanticsLabel: widget.logoSemanticLabel,
          )
        : null;
    Widget home = AnimatedOpacity(
      opacity: state.section == 0 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Flex(
        direction: Axis.vertical,
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                SizedBox.expand(child: Container(color: colorScheme.surface)),
                SizedBox.expand(
                  child: SmartImage(
                    key: ValueKey('auth-page-background-$backgroundImage'),
                    url: backgroundImage,
                    format: AvailableOutputFormats.jpeg,
                    color: theme.colorScheme.primaryContainer,
                    excludeSemantics: true,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Flex(
                    direction: Axis.vertical,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      widget.logo != null
                          ? ContentContainer(
                              padding: density.symmetric(
                                vertical: 32,
                                horizontal: 16,
                                minHorizontal: 8,
                                minVertical: 16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: widget.logoHeight,
                                  width: widget.logoWidth,
                                  constraints: BoxConstraints(
                                    maxHeight: widget.logoHeight,
                                    maxWidth: widget.logoWidth,
                                  ),
                                  child: widget.logoCircle
                                      ? CircleAvatar(
                                          child: AspectRatio(
                                            aspectRatio: 1 / 1,
                                            child: ClipOval(child: logoImage),
                                          ),
                                        )
                                      : logoImage,
                                ),
                              ),
                            )
                          : const SizedBox(),
                      Container(
                        color: theme.colorScheme.surface,
                        child: SafeArea(
                          child: ContentContainer(
                            padding: density.all(16, min: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  width: double.infinity,
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      widget.title ??
                                          locales.get('page-auth--title'),
                                      style: textTheme.displayMedium?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: density.gap(16)),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    widget.description ??
                                        locales.get('page-auth--description'),
                                    style: textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                SizedBox(height: density.gap(16)),
                                ...homeButtonOptions,
                                ?legalConsent,
                                Padding(
                                  padding: density.only(
                                    top: 16,
                                    minVertical: 8,
                                  ),
                                  child: Text(
                                    stateGlobal.appVersion ?? '',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget baseContainer({children = List}) {
      return AnimatedOpacity(
        opacity: state.section == 0 ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Container(
            padding: density.all(16, min: 8),
            constraints: const BoxConstraints(maxWidth: 600),
            child: SafeArea(
              child: Flex(
                mainAxisAlignment: MainAxisAlignment.center,
                direction: Axis.vertical,
                children: children,
              ),
            ),
          ),
        ),
      );
    }

    Widget buttonCancel = SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        icon: const Icon(Icons.close),
        label: Text(locales.get('label--cancel').toUpperCase()),
        onPressed: resetView,
      ),
    );

    List<Widget> sectionsPhoneNumber = [
      SizedBox(
        width: double.maxFinite,
        child: PhoneInput(
          value: state.phone,
          onChanged: (value) {
            state.phone = value;
            if (mounted) setState(() {});
          },
        ),
      ),
      spacerLarge,
    ];

    if (state.phoneValid != null) {
      sectionsPhoneNumber.add(
        actionButton(
          icon: Icons.send_rounded,
          label: locales.get('label--verify').toUpperCase(),
          onPressed: verifyPhoneNumber,
        ),
      );
    }
    sectionsPhoneNumber.add(spacer);
    sectionsPhoneNumber.add(buttonCancel);
    Widget sectionPhoneNumber = baseContainer(children: sectionsPhoneNumber);

    List<Widget> sectionsPhoneVerification = [
      SizedBox(
        width: double.maxFinite,
        child: InputData(
          value: state.phoneVerificationCode,
          type: InputDataType.string,
          keyboardType: TextInputType.number,
          label: locales.get('page-auth--input--verification-code'),
          hintText: locales.get('page-auth--input--verification-code'),
          semanticsLabel: locales.get('page-auth--input--verification-code'),
          semanticHint: locales.get('label--verify'),
          automationKey: 'auth_phone-verification_input_code',
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.singleLineFormatter,
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            state.phoneVerificationCode = value;
            if (mounted) setState(() {});
          },
          onComplete: (value) {
            state.phoneVerificationCode = value;
            if (mounted) setState(() {});
          },
          onSubmit: (value) {
            state.phoneVerificationCode = value;
            if (!(state.phoneVerificationCode != null &&
                state.phoneVerificationCode!.length == 6)) {
              return;
            }
            if (mounted) setState(() {});
            if (kIsWeb) {
              confirmCodeWeb();
            } else {
              signInWithPhoneNumber();
            }
          },
        ),
      ),
      spacerLarge,
    ];
    if (state.phoneVerificationCode != null &&
        state.phoneVerificationCode!.length == 6) {
      sectionsPhoneVerification.add(
        actionButton(
          label: locales.get('label--sign-in-with-phone'),
          onPressed: loading
              ? null
              : () {
                  if (kIsWeb) {
                    confirmCodeWeb();
                  } else {
                    signInWithPhoneNumber();
                  }
                },
        ),
      );
    }
    sectionsPhoneVerification.add(spacer);
    sectionsPhoneVerification.add(buttonCancel);
    Widget sectionPhoneVerification = baseContainer(
      children: sectionsPhoneVerification,
    );

    // Step 3: the address the sign-in link is sent to. There is deliberately no
    // password or confirmation field: the link itself is the credential.
    List<Widget> sectionsEmail = [
      SizedBox(
        width: double.maxFinite,
        child: InputData(
          value: state.email,
          type: InputDataType.email,
          keyboardType: TextInputType.emailAddress,
          validator: InputValidation(locales: locales).validateEmail,
          label: locales.get('page-auth--email--input'),
          hintText: locales.get('page-auth--email--input'),
          semanticsLabel: locales.get('page-auth--email--input'),
          semanticHint: locales.get('label--email-me-a-sign-in-link'),
          automationKey: 'auth_email_input_email',
          autofillHints: const [AutofillHints.email],
          onChanged: (value) {
            state.email = value;
            if (mounted) setState(() {});
          },
          onComplete: (value) {
            state.email = value;
            if (mounted) setState(() {});
          },
        ),
      ),
      spacerLarge,
    ];
    if (state.emailValid != null) {
      sectionsEmail.add(
        actionButton(
          icon: Icons.send_rounded,
          label: locales.get('label--email-me-a-sign-in-link').toUpperCase(),
          semanticHint: locales.get('label--email-me-a-sign-in-link'),
          automationKey: 'auth_email_button_send-link',
          onPressed: loading ? null : sendEmailLink,
        ),
      );
    }
    sectionsEmail.add(spacer);
    sectionsEmail.add(buttonCancel);
    Widget sectionEmail = baseContainer(children: sectionsEmail);

    // Step 4: the inbox wait. Shown after a link is sent, and also when an
    // incoming link has to be matched to an address the user typed by hand
    // (a link opened on a device that never requested it).
    List<Widget> sectionsEmailLinkSent = [
      SizedBox(
        width: double.infinity,
        child: Semantics(
          header: true,
          child: Text(
            locales.get('page-auth--email-link-sent'),
            style: textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
      SizedBox(height: density.gap(8)),
      SizedBox(
        width: double.infinity,
        child: Text(
          locales.get('page-auth--email-link-sent-body', {
            'email': state.email ?? '',
          }),
          style: textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      spacerLarge,
    ];
    if (state.awaitingEmailForLink) {
      sectionsEmailLinkSent.add(
        SizedBox(
          width: double.maxFinite,
          child: InputData(
            value: state.email,
            type: InputDataType.email,
            keyboardType: TextInputType.emailAddress,
            validator: InputValidation(locales: locales).validateEmail,
            label: locales.get('page-auth--email-link-missing-email'),
            hintText: locales.get('page-auth--email--input'),
            semanticsLabel: locales.get('page-auth--email-link-missing-email'),
            semanticHint: locales.get('label--verify'),
            automationKey: 'auth_email-link_input_email',
            autofillHints: const [AutofillHints.email],
            onChanged: (value) {
              state.email = value;
              if (mounted) setState(() {});
            },
            onComplete: (value) {
              state.email = value;
              if (mounted) setState(() {});
            },
          ),
        ),
      );
      if (state.emailValid != null && state.returnUrl != null) {
        sectionsEmailLinkSent.add(spacerLarge);
        sectionsEmailLinkSent.add(
          actionButton(
            icon: Icons.check_circle_outline,
            label: locales.get('label--verify').toUpperCase(),
            semanticHint: locales.get('label--verify'),
            automationKey: 'auth_email-link_button_complete',
            onPressed: loading ? null : confirmEmailLink,
          ),
        );
      }
    } else {
      sectionsEmailLinkSent.add(
        actionButton(
          icon: Icons.refresh_rounded,
          label: locales.get('label--resend-link').toUpperCase(),
          semanticHint: locales.get('label--email-link-cooldown', {
            'seconds': '30',
          }),
          automationKey: 'auth_email-link_button_resend',
          onPressed: loading ? null : resendEmailLink,
        ),
      );
    }
    sectionsEmailLinkSent.add(spacer);
    sectionsEmailLinkSent.add(
      SizedBox(
        width: double.infinity,
        child: AgentElement(
          id: 'auth_email-link_button_change-email',
          type: AgentElementType.button,
          label: locales.get('label--change-email'),
          activator: () async => changeEmail(),
          child: TextButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: Text(locales.get('label--change-email').toUpperCase()),
            onPressed: changeEmail,
          ),
        ),
      ),
    );
    sectionsEmailLinkSent.add(buttonCancel);
    Widget sectionEmailLinkSent = baseContainer(
      children: sectionsEmailLinkSent,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SizedBox.expand(
        child: IndexedStack(
          index: state.section,
          children: <Widget>[
            home,
            sectionPhoneNumber,
            sectionPhoneVerification,
            sectionEmail,
            sectionEmailLinkSent,
          ],
        ),
      ),
    );
  }
}
