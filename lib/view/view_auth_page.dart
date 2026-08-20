import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../component/alert_data.dart';
import '../component/content_container.dart';
import '../component/input_data.dart';
import '../component/phone_input.dart';
import '../component/smart_image.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/auth_service.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_analytics.dart';
import '../state/state_global.dart';
import '../state/state_view_auth.dart';

/// Re-exports the authentication seam so importers of this view keep access to
/// [AuthService], [FirebaseAuthService], `googleSignIn`, and `googleProvider`,
/// which used to be declared here.
export '../helper/auth_service.dart';

/// Provides a full-screen authentication page with multiple sign-in options.
///
/// [ViewAuthPage] supports phone number authentication, Google Sign-In, Apple
/// Sign-In, and anonymous authentication. The page displays a configurable logo,
/// title, description, and background image, along with policy links required
/// for user consent flows.
class ViewAuthPage extends StatefulWidget {
  const ViewAuthPage({
    super.key,
    this.loader,
    this.image,
    this.phone = false,
    this.google = false,
    this.apple = false,
    this.anonymous = false,
    this.googleClientId,
    this.androidPackageName,
    this.iOSBundleId,
    this.policies,
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

  /// Sets the link continue/state URL
  final String url;
  final String? policies;
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
  bool policiesAccepted = false;
  final List<String> googleScopes = <String>['openid', 'email'];
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    loading = false;
    auth = widget.authService ?? FirebaseAuthService();
    policiesAccepted = false;
  }

  @override
  Widget build(BuildContext context) {
    final stateGlobal = Provider.of<StateGlobal>(context);
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);
    final state = Provider.of<StateViewAuth>(context);
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final height = MediaQuery.of(context).size.height;
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
    /// Several callers run after an awaited Firebase call, so the guard is
    /// centralized here: unlike [alertData], an announcement needs this
    /// element's live [View] and cannot fall back to a root context.
    void announce(String message) {
      if (!context.mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
      );
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
      announce(widget.title ?? locales.get('page-auth--title'));
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
      announce(heading);
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
      announce(message);
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
      announce(locales.get('page-auth--input--verification-code'));
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
        announce(locales.get('alert--sign-in-failed'));
      } finally {
        resetView();
      }
    }

    /// Acton button for general use
    Widget actionButton({
      label = String,
      onPressed = VoidCallback,
      icon = Icons.navigate_next,
    }) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
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
            announce(locales.get('label--phone-number'));
          };
          break;
        case 'google':
          text = locales.get('label--sign-in-google');
          icon = Icons.link;
          action = signInGoogle;
          break;
      }
      if (widget.policies != null && !policiesAccepted && !loading) {
        final baseAction = action;
        action = () async {
          try {
            String mdFromFile = await rootBundle.loadString(widget.policies!);
            alertData(
              type: AlertType.basic,
              widget: AlertWidget.dialog,
              child: SizedBox(
                width: double.maxFinite,
                height: height * 0.5,
                child: Markdown(
                  styleSheet: MarkdownStyleSheet.largeFromTheme(theme),
                  selectable: true,
                  // shrinkWrap: true,
                  data: mdFromFile,
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 16,
                  ),
                ),
              ),
              action: ButtonOptions(
                label: locales.get('label--accept'),
                icon: Icons.check,
                onTap: () {
                  policiesAccepted = true;
                  if (mounted) setState(() {});
                  baseAction();
                },
              ),
              dismiss: ButtonOptions(
                label: locales.get('label--reject'),
                icon: Icons.cancel,
                onTap: () {
                  policiesAccepted = false;
                  if (mounted) setState(() {});
                },
              ),
            );
          } catch (error) {
            alertData(body: error.toString(), type: AlertType.critical);
            announce(error.toString());
          }
        };
      }
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FilledButton.icon(
          onPressed: () => action(),
          label: Text(text.toUpperCase()),
          icon: Icon(icon),
        ),
      );
    }

    String backgroundImage =
        widget.image ??
        'https://images.unsplash.com/photo-1615406020658-6c4b805f1f30';
    Widget spacer = const SizedBox(width: 8, height: 8);
    Widget spacerLarge = const SizedBox(width: 16, height: 16);
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
                SizedBox.expand(child: Container(color: Colors.grey.shade50)),
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 32,
                                horizontal: 16,
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
                            padding: const EdgeInsets.all(16),
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
                                Container(height: 16),
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
                                Container(height: 16),
                                ...homeButtonOptions,
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
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
            padding: const EdgeInsets.all(16),
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SizedBox.expand(
        child: IndexedStack(
          index: state.section,
          children: <Widget>[
            home,
            sectionPhoneNumber,
            sectionPhoneVerification,
          ],
        ),
      ),
    );
  }
}
