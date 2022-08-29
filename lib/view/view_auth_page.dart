import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../component/input_data.dart';
import '../component/smart_image.dart';
import '../helper/app_localizations_delegate.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_alert.dart';
import '../state/state_analytics.dart';
import '../state/state_global.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

/// View Auth parameters
class ViewAuthValues {
  String email = '';
  String emailPassword = '';
  String phone = '';
  String phoneCountry;
  int? phoneVerificationCode;
  String? verificationId;

  /// Complete phone number +12233334
  String? phoneValid;

  ViewAuthValues({
    this.email = '',
    this.emailPassword = '',
    this.phone = '',
    this.phoneCountry = '+1',
    this.phoneVerificationCode,
    this.verificationId,
    this.phoneValid,
  });
}

class ViewAuthPage extends StatefulWidget {
  const ViewAuthPage({
    Key? key,
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
    required this.url,
  }) : super(key: key);
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
  late String? emailLink;

  /// Access action link
  void actionLink() async {
    try {
      final linkData = await FirebaseDynamicLinks.instance.getInitialLink();
      final Uri? deepLink = linkData?.link;
      if (linkData == null || deepLink == null) return;
      emailLink = deepLink.toString();
      if (_auth.isSignInWithEmailLink(deepLink.toString())) {
        willSignInWithEmail = true;
        section = 3;
        if (mounted) setState(() {});
      } else {
        if (linkData.utmParameters.containsKey('oobCode')) {
          await _auth.applyActionCode(linkData.utmParameters['oobCode']!);
        }
      }
    } catch (e) {
      // -- TODO: catch error
    }
  }

  @override
  void initState() {
    loading = false;
    section = 0;
    dataAuth = ViewAuthValues();
    webConfirmationResult = null;
    willSignInWithEmail = false;
    actionLink();
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
      actionLink();
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
    final theme = Theme.of(context);
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);
    stateAnalytics.screenName = 'auth';
    void _closeKeyboard() {
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
      _closeKeyboard();
      section = 0;
      dataAuth = ViewAuthValues();
      if (mounted) setState(() {});
    }

    /// Get phone number
    dataAuth.phoneValid = dataAuth.phoneCountry.isNotEmpty &&
            dataAuth.phone.isNotEmpty &&
            dataAuth.phone.length > 4
        ? '${dataAuth.phoneCountry}${dataAuth.phone}'
        : null;

    if (loading) {
      return widget.loader ?? const LoadingScreen();
    }

    final locales = AppLocalizations.of(context)!;
    TextTheme textTheme = Theme.of(context).textTheme;
    final alert = Provider.of<StateAlert>(context, listen: false);

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
        brightness: Brightness.dark,
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
    void _verifyPhoneNumber() async {
      assert(dataAuth.phoneValid != null, 'Phone number can\'t be null');
      loading = true;
      bool success = false;
      if (mounted) setState(() {});
      try {
        await verifyIfUserExists({'phoneNumber': dataAuth.phoneValid});
        if (kIsWeb) {
          final confirmationResult =
              await _auth.signInWithPhoneNumber(dataAuth.phoneValid!);
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
          title: error.message ?? error.details['message'],
          type: AlertType.critical,
          brightness: Brightness.dark,
          clear: true,
        ));
      } catch (error) {
        print('confirmationResult failed ----------');
        alert.show(AlertData(
          title: error.toString(),
          type: AlertType.critical,
          brightness: Brightness.dark,
          clear: true,
        ));
      }
      loading = false;
      if (success) {
        section = 2;
      }
      if (mounted) setState(() {});
    }

    Future<void> _confirmCodeWeb() async {
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
          brightness: Brightness.dark,
          clear: true,
        ));
      }
    }

    /// Example code of how to sign in with phone.
    void _signInWithPhoneNumber() async {
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
          brightness: Brightness.dark,
          clear: true,
        ));
      }
    }

    /// Sign in with google function
    void _signInGoogle() async {
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
          title: error.message ?? error.details['message'],
          type: AlertType.critical,
          brightness: Brightness.dark,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          title: error.toString(),
          type: AlertType.critical,
          brightness: Brightness.dark,
          clear: true,
        ));
      }
      loading = false;
      if (mounted) setState(() {});
    }

    /// Email Link Sign-in
    Future<void> _signInWithEmailAndLink() async {
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
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: error.message ?? error.details['message'],
          type: AlertType.critical,
          brightness: Brightness.dark,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          title: error.toString(),
          type: AlertType.critical,
          brightness: Brightness.dark,
          clear: true,
        ));
      }
    }

    /// Email Link Sign-in
    Future<void> _confirmEmail() async {
      try {
        await verifyIfUserExists({'email': dataAuth.email});
        final User? user = (await _auth.signInWithEmailLink(
          email: dataAuth.email,
          emailLink: emailLink!,
        ))
            .user;
        if (user == null) {
          throw Exception('Please try again');
        }
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          title: error.message ?? error.details['message'],
          type: AlertType.critical,
          brightness: Brightness.dark,
          clear: true,
        ));
      } catch (error) {
        alert.show(AlertData(
          title: error.toString(),
          type: AlertType.critical,
          brightness: Brightness.dark,
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
          brightness: Brightness.dark,
          clear: true,
        ));
      }
    }

    signInWithApple() async {
      try {
        // To prevent replay attacks with the credential returned from Apple, we
        // include a nonce in the credential request. When signing in with
        // Firebase, the nonce in the id token returned by Apple, is expected to
        // match the sha256 hash of `rawNonce`.
        final rawNonce = generateNonce();
        final nonce = sha256ofString(rawNonce);

        // Request credential for the currently signed in Apple account.
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );

        // Create an `OAuthCredential` from the credential returned by Apple.
        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
        );

        // Sign in the user with Firebase. If the nonce we generated earlier does
        // not match the nonce in `appleCredential.identityToken`, sign in will fail.
        final User user =
            (await _auth.signInWithCredential(oauthCredential)).user!;
        final User currentUser = _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        resetView();
      } catch (error) {
        if (kDebugMode) print(error);
        alert.show(AlertData(
          title: locales.get('alert--sign-in-failed'),
          type: AlertType.critical,
          brightness: Brightness.dark,
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
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(color: Colors.white)),
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
          action = _signInGoogle;
          break;
        case 'email':
          text = locales.get('label--sign-in-email');
          icon = Icons.attach_email;
          action = () {
            section = 3;
            if (mounted) setState(() {});
          };
      }
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FloatingActionButton.extended(
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
    if (widget.apple && !kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      homeButtonOptions.add(authButton('apple'));
    }
    if (widget.google) homeButtonOptions.add(authButton('google'));
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
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(16),
                          // decoration: BoxDecoration(
                          //   gradient: LinearGradient(
                          //     begin: Alignment.topCenter,
                          //     end: Alignment.bottomCenter,
                          //     stops: [0.0, 0.5, 1.0],
                          //     colors: [
                          //       Color.fromRGBO(0, 0, 0, 0.0),
                          //       Color.fromRGBO(0, 0, 0, 0.2),
                          //       Color.fromRGBO(0, 0, 0, 0.4),
                          //     ],
                          //   ),
                          // ),
                          child: SafeArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    locales.get('page-auth--title'),
                                    style: textTheme.headline6,
                                    // textAlign: TextAlign.center,
                                  ),
                                ),
                                Container(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    locales.get('page-auth--description'),
                                    style: textTheme.subtitle1,
                                    // textAlign: TextAlign.center,
                                  ),
                                ),
                                Container(height: 16),
                                ...homeButtonOptions,
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    "${locales.get('label--version')}: ${stateGlobal.packageInfo.version}+${stateGlobal.packageInfo.buildNumber}",
                                    style: textTheme.caption,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
      child: ElevatedButton.icon(
        icon: const Icon(Icons.close),
        style: ButtonStyle(
            backgroundColor:
                MaterialStateProperty.all<Color>(Colors.grey.shade800)),
        label: Text(locales.get('label--cancel').toUpperCase()),
        onPressed: resetView,
      ),
    );

    List<Widget> sectionsPhoneNumber = [
      Flex(
        direction: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CountryCodePicker(
            onChanged: (CountryCode countryCode) {
              dataAuth.phoneCountry = countryCode.toString();
              if (mounted) setState(() {});
            },
            // Initial selection and favorite can be one of code ('IT') OR DIAL_CODE('+39')
            initialSelection: 'US',
            favorite: const ['US'],
            // optional. Shows only country name and flag
            showCountryOnly: true,
            // optional. Shows only country name and flag when popup is closed.
            showOnlyCountryWhenClosed: false,
            // optional. aligns the flag and the Text left
            alignLeft: false,
            // dialogTextStyle: TextStyle(color: Colors.black),
            // hideSearch: true,
            // dialogTextStyle: TextStyle(color: Colors.black),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          ),
          spacer,
          Expanded(
            child: InputData(
              value: int.tryParse(dataAuth.phone),
              type: InputDataType.int,
              hintText: locales.get('label--phone-number'),
              maxLength: 14,
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    dataAuth.phone = (value ?? '').toString();
                  });
                }
              },
            ),
          ),
        ],
      ),
      spacerLarge,
    ];

    if (dataAuth.phoneValid != null) {
      sectionsPhoneNumber.add(
        actionButton(
          icon: Icons.send_rounded,
          label: locales.get('label--verify').toUpperCase(),
          onPressed: _verifyPhoneNumber,
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
          if (mounted) {
            setState(() {
              dataAuth.email = value ?? '';
            });
          }
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
              await _confirmEmail();
            } else {
              await _signInWithEmailAndLink();
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
            if (mounted) {
              setState(() {
                dataAuth.phoneVerificationCode = value;
              });
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
          onPressed: () {
            if (kIsWeb) {
              _confirmCodeWeb();
            } else {
              _signInWithPhoneNumber();
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
      body: SizedBox.expand(
        child: Container(
          color: theme.backgroundColor,
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
