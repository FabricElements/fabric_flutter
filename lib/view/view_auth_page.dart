import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../component/content_container.dart';
import '../component/input_data.dart';
import '../component/smart_image.dart';
import '../helper/app_localizations_delegate.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_alert.dart';
import '../state/state_analytics.dart';
import '../state/state_dynamic_links.dart';
import '../state/state_global.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

/// View Auth parameters
class ViewAuthValues {
  String email = '';
  String emailPassword = '';
  String phone = '';
  int? phoneVerificationCode;
  String? verificationId;

  /// Complete phone number +12233334
  String? phoneValid;

  ViewAuthValues({
    this.email = '',
    this.emailPassword = '',
    this.phone = '',
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
    this.verify = false,
    this.phone = false,
    this.email = false,
    this.google = false,
    this.apple = false,
    this.anonymous = false,
    this.googleClientId,
    this.androidPackageName,
    this.iOSBundleId,
    this.policies,
    required this.url,
    this.logo,
    this.logoHeight = 200,
    this.logoWidth = 200,
    this.logoCircle = false,
  });

  final Widget? loader;
  final String? image;
  final bool verify;
  final bool phone;
  final bool email;
  final bool google;
  final bool apple;
  final bool anonymous;
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

  @override
  State<ViewAuthPage> createState() => _ViewAuthPageState();
}

class _ViewAuthPageState extends State<ViewAuthPage>
    with WidgetsBindingObserver {
  late bool loading;
  late int section;
  late ViewAuthValues dataAuth;
  ConfirmationResult? webConfirmationResult;
  late bool willSignInWithEmail;
  String? emailLink;
  bool policiesAccepted = false;

  @override
  void initState() {
    loading = false;
    section = 0;
    dataAuth = ViewAuthValues();
    webConfirmationResult = null;
    willSignInWithEmail = false;
    policiesAccepted = false;
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
    }
    super.didChangeAppLifecycleState(state);
  }

  /// Validate if user exists or fail
  Future<void> verifyIfUserExists(Map<String, dynamic> data) async {
    if (widget.verify) {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('user-actions-exists');
      await callable.call(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateGlobal = Provider.of<StateGlobal>(context);
    final stateDynamicLinks = Provider.of<StateDynamicLinks>(context);
    final theme = Theme.of(context);
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);
    final locales = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final alert = Provider.of<StateAlert>(context, listen: false);

    /// Access action link
    void actionLink() async {
      try {
        final linkData = stateDynamicLinks.pendingDynamicLinkData;
        final Uri? deepLink = linkData?.link;
        if (deepLink == null) return;
        emailLink = deepLink.toString();
        if (_auth.isSignInWithEmailLink(deepLink.toString())) {
          willSignInWithEmail = true;
          section = 3;
          if (mounted) setState(() {});
        } else {
          if (linkData != null &&
              linkData.utmParameters.containsKey('oobCode')) {
            await _auth.applyActionCode(linkData.utmParameters['oobCode']!);
          }
        }
      } catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      actionLink();
    });

    stateAnalytics.screenName = 'auth';
    void closeKeyboard() {
      if (kIsWeb) return;
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          FocusScope.of(context).requestFocus(FocusNode());
        } catch (error) {
          //
        }
      }
    }

    void resetView() {
      closeKeyboard();
      section = 0;
      dataAuth = ViewAuthValues();
      if (mounted) setState(() {});
    }

    /// Get phone number
    dataAuth.phoneValid = dataAuth.phone.isNotEmpty && dataAuth.phone.length > 4
        ? dataAuth.phone
        : null;

    if (loading) {
      return widget.loader ?? const LoadingScreen();
    }

    /// Verification completed: Sign in with credentials
    verificationCompleted(AuthCredential phoneAuthCredential) async {
      await _auth.signInWithCredential(phoneAuthCredential);
      alert.show(AlertData(
        title: locales.get('alert--received-phone-auth-credential'),
        clear: true,
      ));
    }

    /// Verification Failed
    verificationFailed(FirebaseAuthException authException) {
      alert.show(AlertData(
        title:
            '${locales.get('alert--phone-number-verification-failed')}. ${authException.message} -- Code: ${authException.code}',
        type: AlertType.critical,
        clear: true,
      ));
    }

    /// SMS auth code sent
    codeSent(String verificationId, [int? forceResendingToken]) {
      dataAuth.verificationId = verificationId;
      alert.show(AlertData(
        title: locales.get('alert--check-phone-verification-code'),
        type: AlertType.success,
        duration: 3,
        clear: true,
      ));
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
        await verifyIfUserExists({'phone': dataAuth.phoneValid});
        if (kIsWeb || Platform.isMacOS) {
          final confirmationResult = await _auth.signInWithPhoneNumber(
            dataAuth.phoneValid!,
            // RecaptchaVerifier(
            //   container: 'recaptcha',
            //   size: RecaptchaVerifierSize.compact,
            //   theme: RecaptchaVerifierTheme.dark,
            //   auth: _auth.app,
            // ),
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
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
          clear: true,
        ));
      } catch (error) {
        debugPrint('confirmationResult failed ----------');
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
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
            'Enter valid confirmation code');
        assert(webConfirmationResult?.verificationId != null,
            'Please input sms code received after verifying phone number');
        final UserCredential credential = await webConfirmationResult!
            .confirm(dataAuth.phoneVerificationCode.toString());
        final User user = credential.user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        resetView();
      } catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
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
            'Enter valid confirmation code');
        final AuthCredential credential = PhoneAuthProvider.credential(
          verificationId: dataAuth.verificationId!,
          smsCode: dataAuth.phoneVerificationCode.toString(),
        );
        final User user = (await _auth.signInWithCredential(credential)).user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        resetView();
      } catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
      }
      loading = false;
      if (mounted) setState(() {});
    }

    /// Sign in with google function
    void signInGoogle() async {
      loading = true;
      if (mounted) setState(() {});
      try {
        if (kIsWeb) {
          assert(
              widget.googleClientId != null &&
                  widget.googleClientId!.isNotEmpty,
              'googleClientId missing');
        }

        final googleSignInAccount = GoogleSignIn(
          clientId: widget.googleClientId,
          scopes: ['email'],
        );
        if (await googleSignInAccount.isSignedIn()) {
          /// Disconnect previews account
          await googleSignInAccount.disconnect();
        }
        // Trigger the authentication flow
        final googleUser = await googleSignInAccount.signIn();
        // Obtain the auth details from the request
        final GoogleSignInAuthentication? googleAuth =
            await googleUser?.authentication;

        await verifyIfUserExists({'email': googleUser?.email});
        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
        // Once signed in, return the UserCredential and get the User object
        final user = (await _auth.signInWithCredential(credential)).user;
        if (user == null) {
          throw Exception('Please try again');
        }
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
          clear: true,
        ));
      } on FirebaseAuthException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
          clear: true,
        ));
      } on FirebaseException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
      }
      loading = false;
      if (mounted) setState(() {});
    }

    /// Email Link Sign-in
    Future<void> signInWithEmailAndLink() async {
      try {
        await verifyIfUserExists({'email': dataAuth.email});
        await _auth.sendSignInLinkToEmail(
          email: dataAuth.email,
          actionCodeSettings: ActionCodeSettings(
            androidInstallApp: true,
            androidMinimumVersion: '12',
            androidPackageName: widget.androidPackageName,
            handleCodeInApp: true,
            iOSBundleId: widget.iOSBundleId,
            url: widget.url,
          ),
        );
        alert.show(AlertData(
          title: 'An email has been sent to ${dataAuth.email}',
          type: AlertType.success,
          duration: 3,
          clear: true,
        ));
        section = 0;
        if (mounted) setState(() {});
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
      }
    }

    /// Email Link Sign-in
    Future<void> confirmEmail() async {
      try {
        await verifyIfUserExists({'email': dataAuth.email});
        final User? user = (await _auth.signInWithEmailLink(
          email: dataAuth.email,
          emailLink: emailLink!,
        ))
            .user;
        stateDynamicLinks.pendingDynamicLinkData = null;
        if (user == null) {
          throw Exception('Please try again');
        }
        resetView();
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
      }
    }

    /// Sign in with Apple
    /// Generates a cryptographically secure random nonce, to be included in a
    /// credential request.
    String generateNonce([int length = 32]) {
      const charset =
          '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
      final random = Random.secure();
      return List.generate(
          length, (_) => charset[random.nextInt(charset.length)]).join();
    }

    /// Returns the sha256 hash of [input] in hex notation.
    String sha256ofString(String input) {
      final bytes = utf8.encode(input);
      final digest = sha256.convert(bytes);
      return digest.toString();
    }

    signInAnonymously() async {
      try {
        final userCredential = await _auth.signInAnonymously();
        final User user = userCredential.user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        alert.show(AlertData(
          title: 'Signed in with temporary account.',
          type: AlertType.success,
          clear: true,
        ));
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: error.message ?? error.details['message'],
          type: AlertType.critical,
          clear: true,
        ));
      } on FirebaseAuthException catch (e) {
        if (kDebugMode) print(e);
        String errorMessage = locales.get('alert--sign-in-failed');
        switch (e.code) {
          case 'operation-not-allowed':
            errorMessage =
                'Anonymous auth hasn\'t been enabled for this project.';
            break;
        }
        alert.show(AlertData(
          title: errorMessage,
          type: AlertType.critical,
          clear: true,
        ));
      } on FirebaseException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
          clear: true,
        ));
      }
    }

    signInWithApple() async {
      try {
        final appleProvider = AppleAuthProvider();
        if (kIsWeb) {
          await FirebaseAuth.instance.signInWithPopup(appleProvider);
        } else {
          await FirebaseAuth.instance.signInWithProvider(appleProvider);
        }
        resetView();
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
          clear: true,
        ));
      } on FirebaseAuthException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
          clear: true,
        ));
      } on FirebaseException catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          body: error.message,
          type: AlertType.critical,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed: '),
          body: error.toString(),
          type: AlertType.critical,
          clear: true,
        ));
      }
    }

    /// Acton button for general use
    Widget actionButton(
        {label = String,
        onPressed = VoidCallback,
        icon = Icons.navigate_next}) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
    }

    Widget authButton(provider) {
      String text = locales.get('label--sign-in');
      var icon = Icons.email;
      VoidCallback action = () {
        if (kDebugMode) print('clicked: $provider');
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
        case 'email':
          text = locales.get('label--sign-in-email');
          icon = Icons.attach_email;
          action = () {
            section = 3;
            if (mounted) setState(() {});
          };
      }
      if (widget.policies != null && !policiesAccepted) {
        final baseAction = action;
        action = () async {
          try {
            String mdFromFile = await rootBundle.loadString(widget.policies!);
            alert.show(AlertData(
              type: AlertType.basic,
              widget: AlertWidget.dialog,
              child: SizedBox(
                height: double.maxFinite,
                width: double.maxFinite,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
                  child: Markdown(
                    selectable: true,
                    shrinkWrap: true,
                    data: mdFromFile,
                    padding: EdgeInsets.zero,
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
            ));
          } catch (error) {
            alert.show(AlertData(
              body: error.toString(),
              type: AlertType.critical,
            ));
          }
        };
      }
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FilledButton.icon(
          onPressed: action,
          label: Text(text.toUpperCase()),
          icon: Icon(icon),
        ),
      );
    }

//    final Widget svgIcon = Container(height: 10, width: 10);
    String backgroundImage = widget.image ??
        'https://images.unsplash.com/photo-1615406020658-6c4b805f1f30';
    Widget spacer = const SizedBox(width: 8, height: 8);
    Widget spacerLarge = const SizedBox(width: 16, height: 16);
    List<Widget> homeButtonOptions = [];
    if (widget.apple && (kIsWeb || Platform.isIOS || Platform.isMacOS)) {
      homeButtonOptions.add(authButton('apple'));
    }
    if (widget.google && (kIsWeb || Platform.isIOS || Platform.isAndroid)) {
      homeButtonOptions.add(authButton('google'));
    }
    if (widget.phone && (kIsWeb || Platform.isIOS || Platform.isAndroid)) {
      homeButtonOptions.add(authButton('phone'));
    }
    if (widget.email && !kIsWeb) homeButtonOptions.add(authButton('email'));
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
                SizedBox.expand(
                  child: Container(color: Colors.grey.shade50),
                ),
                SizedBox.expand(
                  child: SmartImage(
                    url: backgroundImage,
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
                              padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16, top: 16),
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
                                          // backgroundColor: color,
                                          child: AspectRatio(
                                            aspectRatio: 1 / 1,
                                            child: ClipOval(
                                              child:
                                                  SmartImage(url: widget.logo),
                                            ),
                                          ),
                                        )
                                      : SmartImage(url: widget.logo),
                                ),
                              ),
                            )
                          : const SizedBox(),
                      Container(
                        color: theme.colorScheme.background,
                        child: SafeArea(
                          child: ContentContainer(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, top: 16, bottom: 48),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    locales.get('page-auth--title'),
                                    style: textTheme.titleLarge,
                                    // textAlign: TextAlign.center,
                                  ),
                                ),
                                Container(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    locales.get('page-auth--description'),
                                    style: textTheme.titleMedium,
                                    // textAlign: TextAlign.center,
                                  ),
                                ),
                                Container(height: 16),
                                ...homeButtonOptions,
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(stateGlobal.appVersion ?? '',
                                      style: textTheme.bodySmall),
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
        child: InputData(
          value: dataAuth.phone,
          type: InputDataType.phone,
          icon: Icons.phone,
          label: locales.get('label--phone-number'),
          isExpanded: true,
          maxLength: 14,
          onChanged: (value) {
            dataAuth.phone = (value ?? '').toString();
            if (mounted) setState(() {});
          },
          onComplete: (value) {
            dataAuth.phone = (value ?? '').toString();
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

    List<Widget> sectionsEmailLink = [
      InputData(
        value: dataAuth.email,
        type: InputDataType.email,
        hintText: locales.get('label--enter-an-email'),
        onChanged: (value) {
          dataAuth.email = value ?? '';
          if (mounted) setState(() {});
        },
        onComplete: (value) {
          dataAuth.email = value ?? '';
          if (mounted) setState(() {});
        },
      ),
      spacerLarge,
    ];
    if (dataAuth.email.length > 4) {
      String actionLabel = locales.get('label--verify');
      IconData actionIcon = Icons.insert_link;
      if (willSignInWithEmail) {
        actionIcon = Icons.check;
        actionLabel = locales.get('label--sing-in');
      }
      sectionsEmailLink.add(
        actionButton(
          icon: actionIcon,
          label: actionLabel.toUpperCase(),
          onPressed: () async {
            if (willSignInWithEmail) {
              await confirmEmail();
            } else {
              await signInWithEmailAndLink();
            }
          },
        ),
      );
    }
    sectionsEmailLink.add(spacer);
    sectionsEmailLink.add(buttonCancel);

    Widget sectionEmail = baseContainer(children: sectionsEmailLink);

    List<Widget> sectionsPhoneVerification = [
      SizedBox(
        width: double.maxFinite,
        child: InputData(
          isExpanded: true,
          value: dataAuth.phoneVerificationCode,
          type: InputDataType.int,
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
                dataAuth.phoneVerificationCode.toString().length == 6)) return;
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
      sectionsPhoneVerification.add(actionButton(
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
      ));
    }
    sectionsPhoneVerification.add(spacer);
    sectionsPhoneVerification.add(buttonCancel);
    Widget sectionPhoneVerification = baseContainer(
      children: sectionsPhoneVerification,
    );

    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          color: theme.colorScheme.background,
          child: IndexedStack(
            index: section,
            children: <Widget>[
              home,
              sectionPhoneNumber,
              sectionPhoneVerification,
              sectionEmail,
            ],
          ),
        ),
      ),
    );
  }
}
