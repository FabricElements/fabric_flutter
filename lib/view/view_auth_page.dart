import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../component/content_container.dart';
import '../component/input_data.dart';
import '../component/phone_input.dart';
import '../component/smart_image.dart';
import '../helper/app_localizations_delegate.dart';
import '../helper/log_color.dart';
import '../helper/options.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_alert.dart';
import '../state/state_analytics.dart';
import '../state/state_global.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final GoogleSignIn googleSignIn = GoogleSignIn.instance;
GoogleAuthProvider googleProvider = GoogleAuthProvider();

/// View Auth parameters
/// IMPORTANT: [key] Use [authPageKey] to access the state of the ViewAuthPage without loosing context with recaptcha
/// Create a global key to access the state of the ViewAuthPage without loosing context with recaptcha
class ViewAuthValues {
  String? phone;
  int? phoneVerificationCode;
  String? verificationId;

  /// Complete phone number +12233334
  String? phoneValid;

  ViewAuthValues({
    this.phone,
    this.phoneVerificationCode,
    this.verificationId,
    this.phoneValid,
  });
}

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
  int section = 0;
  ViewAuthValues dataAuth = ViewAuthValues();
  ConfirmationResult? webConfirmationResult;
  bool policiesAccepted = false;
  final List<String> googleScopes = <String>['openid', 'email'];

  @override
  void initState() {
    loading = false;
    webConfirmationResult = null;
    policiesAccepted = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final stateGlobal = Provider.of<StateGlobal>(context);
    final theme = Theme.of(context);
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);
    final locales = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final alert = Provider.of<StateAlert>(context, listen: false);
    final height = MediaQuery.of(context).size.height;

    stateAnalytics.screenName = 'auth';

    void resetView() {
      // Close Keyboard
      FocusScope.of(context).requestFocus(FocusNode());
      section = 0;
      dataAuth = ViewAuthValues();
      if (mounted) setState(() {});
    }

    /// Get phone number
    dataAuth.phoneValid =
        dataAuth.phone != null &&
            dataAuth.phone!.isNotEmpty &&
            dataAuth.phone!.length > 4
        ? dataAuth.phone
        : null;

    if (loading) {
      return widget.loader ?? const LoadingScreen();
    }

    /// Verification completed: Sign in with credentials
    verificationCompleted(AuthCredential phoneAuthCredential) async {
      await _auth.signInWithCredential(phoneAuthCredential);
      alert.show(
        AlertData(
          title: locales.get('alert--received-phone-auth-credential'),
          clear: true,
        ),
      );
    }

    /// Verification Failed
    verificationFailed(FirebaseAuthException authException) {
      alert.show(
        AlertData(
          title:
              '${locales.get('alert--phone-number-verification-failed')}. ${authException.message} -- Code: ${authException.code}',
          type: AlertType.critical,
          clear: true,
        ),
      );
    }

    /// SMS auth code sent
    codeSent(String verificationId, [int? forceResendingToken]) {
      dataAuth.verificationId = verificationId;
      section = 2;
      if (mounted) setState(() {});
      alert.show(
        AlertData(
          title: locales.get('alert--check-phone-verification-code'),
          type: AlertType.success,
          duration: 3,
          clear: true,
        ),
      );
    }

    /// SMS auth code retrieval timeout
    codeAutoRetrievalTimeout(String verificationId) {
      dataAuth.verificationId = verificationId;
    }

    /// Verify phone number
    void verifyPhoneNumber() async {
      assert(dataAuth.phoneValid != null, 'Phone number can\'t be null');
      loading = true;
      bool success = false;
      if (mounted) setState(() {});
      try {
        if (kIsWeb || Platform.isMacOS) {
          final confirmationResult = await _auth.signInWithPhoneNumber(
            dataAuth.phoneValid!,
          );
          dataAuth.verificationId = confirmationResult.verificationId;
          webConfirmationResult = confirmationResult;
        } else {
          await _auth.verifyPhoneNumber(
            forceResendingToken: 3,
            phoneNumber: dataAuth.phoneValid!,
            timeout: const Duration(minutes: 2),
            verificationCompleted: verificationCompleted,
            verificationFailed: verificationFailed,
            codeSent: codeSent,
            codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
          );
        }
        success = true;
      } catch (error) {
        debugPrint('confirmationResult failed ----------');
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.toString(),
            type: AlertType.critical,
            clear: true,
          ),
        );
      }
      loading = false;
      if (success) {
        section = 2;
      }
      if (mounted) setState(() {});
    }

    Future<void> confirmCodeWeb() async {
      loading = true;
      if (mounted) setState(() {});
      try {
        assert(
          dataAuth.phoneVerificationCode != null &&
              dataAuth.phoneVerificationCode.toString().length == 6,
          'Enter valid confirmation code',
        );
        assert(
          webConfirmationResult?.verificationId != null,
          'Please input sms code received after verifying phone number',
        );
        final UserCredential credential = await webConfirmationResult!.confirm(
          dataAuth.phoneVerificationCode.toString(),
        );
        final User user = credential.user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        resetView();
      } catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.toString(),
            type: AlertType.critical,
            clear: true,
          ),
        );
      }
      loading = false;
      if (mounted) setState(() {});
    }

    /// Example code of how to sign in with phone.
    void signInWithPhoneNumber() async {
      loading = true;
      if (mounted) setState(() {});
      try {
        assert(dataAuth.verificationId != null, 'VerificationId missing');
        assert(
          dataAuth.phoneVerificationCode != null &&
              dataAuth.phoneVerificationCode.toString().length == 6,
          'Enter valid confirmation code',
        );
        final AuthCredential credential = PhoneAuthProvider.credential(
          verificationId: dataAuth.verificationId!,
          smsCode: dataAuth.phoneVerificationCode.toString(),
        );
        final User user = (await _auth.signInWithCredential(credential)).user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        resetView();
      } catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.toString(),
            type: AlertType.critical,
            clear: true,
          ),
        );
      }
      loading = false;
      if (mounted) setState(() {});
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
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.message,
            type: AlertType.critical,
            clear: true,
          ),
        );
      } on FirebaseException catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.message,
            type: AlertType.critical,
            clear: true,
          ),
        );
      } catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.toString(),
            type: AlertType.critical,
            clear: true,
          ),
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
        alert.show(
          AlertData(
            title: 'Signed in with temporary account.',
            type: AlertType.success,
            clear: true,
          ),
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
        alert.show(
          AlertData(title: errorMessage, type: AlertType.critical, clear: true),
        );
      } on FirebaseException catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.message,
            type: AlertType.critical,
            clear: true,
          ),
        );
      }
    }

    /// Sign in with Apple
    signInWithApple() async {
      try {
        var appleProvider = AppleAuthProvider();
        appleProvider.addScope('email'); //this scope is required
        if (kIsWeb) {
          await _auth.signInWithPopup(appleProvider);
        } else {
          await _auth.signInWithProvider(appleProvider);
        }
        resetView();
      } on FirebaseAuthException catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.message,
            type: AlertType.critical,
            clear: true,
          ),
        );
      } on FirebaseException catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed'),
            body: error.message,
            type: AlertType.critical,
            clear: true,
          ),
        );
      } catch (error) {
        alert.show(
          AlertData(
            title: locales.get('alert--sign-in-failed: '),
            body: error.toString(),
            type: AlertType.critical,
            clear: true,
          ),
        );
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
            section = 1;
            if (mounted) setState(() {});
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
          loading = true;
          if (mounted) setState(() {});
          try {
            String mdFromFile = await rootBundle.loadString(widget.policies!);
            alert.show(
              AlertData(
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
              ),
            );
          } catch (error) {
            alert.show(
              AlertData(
                body: error.toString(),
                type: AlertType.critical,
                clear: true,
              ),
            );
          }
          loading = false;
          if (mounted) setState(() {});
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
      opacity: section == 0 ? 1 : 0,
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
        opacity: section == 0 ? 0 : 1,
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
          value: dataAuth.phone,
          onChanged: (value) {
            dataAuth.phone = value;
            if (mounted) setState(() {});
          },
        ),
      ),
      spacerLarge,
    ];

    if (dataAuth.phoneValid != null) {
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
          value: dataAuth.phoneVerificationCode,
          type: InputDataType.int,
          keyboardType: TextInputType.number,
          hintText: locales.get('page-auth--input--verification-code'),
          maxLength: 6,
          onChanged: (value) {
            dataAuth.phoneVerificationCode = value;
            if (mounted) setState(() {});
          },
          onComplete: (value) {
            dataAuth.phoneVerificationCode = value;
            if (mounted) setState(() {});
          },
          onSubmit: (value) {
            dataAuth.phoneVerificationCode = value;
            if (!(dataAuth.phoneVerificationCode != null &&
                dataAuth.phoneVerificationCode.toString().length == 6)) {
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
    if (dataAuth.phoneVerificationCode != null &&
        dataAuth.phoneVerificationCode.toString().length == 6) {
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
          index: section,
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
