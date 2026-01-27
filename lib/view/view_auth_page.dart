import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../component/alert_data.dart';
import '../component/content_container.dart';
import '../component/input_data.dart';
import '../component/phone_input.dart';
import '../component/smart_image.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_analytics.dart';
import '../state/state_global.dart';
import '../state/state_view_auth.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final GoogleSignIn googleSignIn = GoogleSignIn.instance;
GoogleAuthProvider googleProvider = GoogleAuthProvider();

/// ViewAuthPage
/// A full screen authentication page with multiple sign-in options
/// Supports:
/// - Phone number authentication
/// - Google Sign-In
/// - Apple Sign-In
/// - Anonymous Sign-In
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
    this.title,
    this.description,
  });

  final Widget? loader;
  final String? image;
  final bool phone;
  final bool google;
  final bool apple;
  final bool anonymous;

  /// @deprecated Google Sign-In Client ID is now set globally
  /// On index.html for web, set the client ID in the meta tag and the script tag:
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
  final String? title;
  final String? description;

  @override
  State<ViewAuthPage> createState() => ViewAuthPageState();
}

class ViewAuthPageState extends State<ViewAuthPage> {
  late bool loading;
  ConfirmationResult? webConfirmationResult;
  bool policiesAccepted = false;
  final List<String> googleScopes = <String>['openid', 'email'];
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    loading = false;
    webConfirmationResult = null;
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

    if (loading || !initialized) {
      return widget.loader ?? const LoadingScreen();
    }

    /// Reset view to initial state
    Future<void> resetView() async {
      loading = true;
      // Close Keyboard
      FocusScope.of(context).requestFocus(FocusNode());
      state.clear();
      await Future.delayed(const Duration(seconds: 1));
      loading = false;
      if (mounted) setState(() {});
    }

    /// Verification completed: Sign in with credentials
    verificationCompleted(AuthCredential phoneAuthCredential) async {
      await _auth.signInWithCredential(phoneAuthCredential);
      alertData(
        context: context,
        body: locales.get('alert--received-phone-auth-credential'),
      );
    }

    /// Verification Failed
    verificationFailed(FirebaseAuthException error) {
      bool authCanceled = error.code == 'canceled';
      if (authCanceled) {
        debugPrint(LogColor.error(error.message ?? error.code));
        return;
      }
      alertData(
        context: context,
        body:
            '${locales.get('alert--phone-number-verification-failed')}. ${error.message} -- Code: ${error.code}',
        type: AlertType.critical,
      );
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
          final confirmationResult = await _auth.signInWithPhoneNumber(
            state.phoneValid!,
          );
          state.verificationId = confirmationResult.verificationId;
          webConfirmationResult = confirmationResult;
        } else {
          await _auth.verifyPhoneNumber(
            forceResendingToken: 3,
            phoneNumber: state.phoneValid!,
            timeout: const Duration(minutes: 2),
            verificationCompleted: verificationCompleted,
            verificationFailed: verificationFailed,
            codeSent: codeSent,
            codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
          );
        }
        success = true;
      } catch (error) {
        debugPrint(LogColor.error('ConfirmationResult Error: $error'));
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
        );
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
              state.phoneVerificationCode.toString().length == 6,
          'Enter valid confirmation code',
        );
        assert(
          webConfirmationResult?.verificationId != null,
          'Please input sms code received after verifying phone number',
        );
        final UserCredential credential = await webConfirmationResult!.confirm(
          state.phoneVerificationCode.toString(),
        );
        final User user = credential.user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        await Future.delayed(const Duration(seconds: 3));
        resetView();
      } catch (error) {
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
        );
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
              state.phoneVerificationCode.toString().length == 6,
          'Enter valid confirmation code',
        );
        final AuthCredential credential = PhoneAuthProvider.credential(
          verificationId: state.verificationId!,
          smsCode: state.phoneVerificationCode.toString(),
        );
        final User user = (await _auth.signInWithCredential(credential)).user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        await Future.delayed(const Duration(seconds: 3));
        resetView();
      } catch (error) {
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
        );
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
        // Sign out if signed in
        // The new API exposes a singleton without a `currentUser` getter.
        // Always attempt signOut first to ensure a fresh sign-in.
        try {
          await googleSignIn.signOut();
        } catch (e) {
          // ignore sign out errors
        }
      } catch (error) {
        //
      }
      try {
        if (kIsWeb) {
          for (var scope in googleScopes) {
            googleProvider.addScope(scope);
          }
          await _auth.signInWithPopup(googleProvider);
        } else {
          // Use `authenticate` from the new API which performs an interactive sign-in.
          final authenticated = await googleSignIn.authenticate(
            scopeHint: googleScopes,
          );
          // `authenticate` in google_sign_in >=7.x returns a non-null
          // GoogleSignInAccount on success or throws on failure, so no null
          // check is necessary here.
          // Get ID token from the authentication object.
          final GoogleSignInAuthentication googleAuth =
              authenticated.authentication;
          // Access token is obtained via the authorization client for the account.
          final clientAuth = await authenticated.authorizationClient
              .authorizationForScopes(googleScopes);
          final credential = GoogleAuthProvider.credential(
            accessToken: clientAuth?.accessToken,
            idToken: googleAuth.idToken,
          );
          await _auth.signInWithCredential(credential);
        }
      } on FirebaseAuthException catch (error) {
        bool authCanceled = error.code == 'canceled';
        if (!authCanceled) {
          alertData(
            context: context,
            title: locales.get('alert--sign-in-failed'),
            body: error.message,
            type: AlertType.critical,
          );
        }
      } on FirebaseException catch (error) {
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
        );
      } catch (error) {
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
        );
      }
      loading = false;
      if (mounted) setState(() {});
    }

    /// Sign in anonymously
    signInAnonymously() async {
      try {
        final userCredential = await _auth.signInAnonymously();
        final User user = userCredential.user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);

        alertData(
          context: context,
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
          alertData(
            context: context,
            body: errorMessage,
            type: AlertType.critical,
          );
        }
      } on FirebaseException catch (error) {
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
        );
      }
    }

    /// Sign in with Apple
    signInWithApple() async {
      try {
        loading = true;
        if (mounted) setState(() {});
        var appleProvider = AppleAuthProvider();
        appleProvider.addScope('email'); //this scope is required
        if (kIsWeb) {
          await _auth.signInWithPopup(appleProvider);
        } else {
          await _auth.signInWithProvider(appleProvider);
        }
      } on FirebaseAuthException catch (error) {
        bool authCanceled = error.code == 'canceled';
        if (!authCanceled) {
          alertData(
            context: context,
            title: locales.get('alert--sign-in-failed'),
            body: error.message,
            type: AlertType.critical,
          );
        }
      } on FirebaseException catch (error) {
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
        );
      } catch (error) {
        alertData(
          context: context,
          title: locales.get('alert--sign-in-failed: '),
          body: error.toString(),
          type: AlertType.critical,
        );
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
              context: context,
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
            alertData(
              context: context,
              body: error.toString(),
              type: AlertType.critical,
            );
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
                    url: backgroundImage,
                    format: AvailableOutputFormats.jpeg,
                    color: theme.colorScheme.primaryContainer,
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
                                            child: ClipOval(
                                              child: SmartImage(
                                                url: widget.logo,
                                                format:
                                                    AvailableOutputFormats.png,
                                                color:
                                                    theme.colorScheme.surface,
                                              ),
                                            ),
                                          ),
                                        )
                                      : SmartImage(
                                          url: widget.logo,
                                          format: AvailableOutputFormats.png,
                                          color: theme.colorScheme.surface,
                                        ),
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
                                  child: Text(
                                    widget.title ??
                                        locales.get('page-auth--title'),
                                    style: textTheme.displayMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
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
          type: InputDataType.int,
          keyboardType: TextInputType.number,
          hintText: locales.get('page-auth--input--verification-code'),
          maxLength: 6,
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
                state.phoneVerificationCode.toString().length == 6)) {
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
        state.phoneVerificationCode.toString().length == 6) {
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
