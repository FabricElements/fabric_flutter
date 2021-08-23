import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../component/smart_image.dart';
import '../helper/alert.dart';
import '../helper/app_localizations_delegate.dart';
import '../placeholder/loading_screen.dart';
import '../state/state_analytics.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final GoogleSignIn _googleSignIn = GoogleSignIn();

class ViewAuthPage extends StatefulWidget {
  ViewAuthPage({
    Key? key,
    this.loader,
  }) : super(key: key);
  final Widget? loader;

  @override
  _ViewAuthPageState createState() => _ViewAuthPageState();
}

class _ViewAuthPageState extends State<ViewAuthPage>
    with WidgetsBindingObserver {
  late bool loading;
  int? section;
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  ConfirmationResult? webConfirmationResult;

  late String areaCode;
  String? _verificationId;
  late String _userEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    loading = false;
    section = 0;
    areaCode = "+1";
    _verificationId = null;
    _userEmail = "";
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    print("change lifecycle");
    if (state == AppLifecycleState.resumed) {
      print("wait...");
      await Future.delayed(Duration(seconds: 3));
      final Uri? link = await _retrieveDynamicLink();
      bool _success = false;
      print("link: $link");
      if (link != null) {
        final User? user = (await _auth.signInWithEmailLink(
          email: _userEmail,
          emailLink: link.toString(),
        ))
            .user;
        if (user != null) {
          print(user.uid);
          _success = true;
        } else {
          _success = false;
        }
      } else {
        _success = false;
      }
      setState(() {});
    }
  }

  Future<Uri?> _retrieveDynamicLink() async {
    final PendingDynamicLinkData? data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri? deepLink = data?.link;
    print("deepLink on auth: $deepLink");
    return deepLink;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    StateAnalytics stateAnalytics =
        Provider.of<StateAnalytics>(context, listen: false);
    stateAnalytics.screenName = "auth";

    if (loading) {
      return widget.loader ?? LoadingScreen();
    }
    void _closeKeyboard() {
      try {
        FocusScope.of(context).requestFocus(FocusNode());
      } catch (error) {}
    }

    AppLocalizations locales = AppLocalizations.of(context)!;
    TextTheme textTheme = Theme.of(context).textTheme;
    Alert alert = Alert(
      context: context,
      mounted: mounted,
    );

    // void _resendCode() async {
    //   loading = true;
    //   if (mounted) setState(() {});
    // }

    /// Example code of how to verify phone number
    void _verifyPhoneNumber() async {
      loading = true;
      bool success = false;
      if (mounted) setState(() {});
      try {
        final PhoneVerificationCompleted verificationCompleted =
            (AuthCredential phoneAuthCredential) async {
          await _auth.signInWithCredential(phoneAuthCredential);
          alert.show(
            text: locales.get("alert--received-phone-auth-credential"),
            type: "default",
          );
        };
        final PhoneVerificationFailed verificationFailed =
            (FirebaseAuthException authException) {
          alert.show(
            text:
                "${locales.get("alert--phone-number-verification-failed")}. ${authException.message} -- Code: ${authException.code}",
            type: "error",
          );
        };

        final PhoneCodeSent codeSent =
            (String verificationId, [int? forceResendingToken]) async {
          _verificationId = verificationId;
          alert.show(
            text: locales.get("alert--check-phone-verification-code"),
            type: "success",
          );
        };
        final PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout =
            (String verificationId) {
          _verificationId = verificationId;
        };
        String phoneNumber = areaCode + _phoneNumberController.text;
        // Validate if user exists
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable("user-actions-exists");
        await callable.call(<String, dynamic>{"phoneNumber": phoneNumber});
        if (kIsWeb) {
          ConfirmationResult confirmationResult =
              await _auth.signInWithPhoneNumber(phoneNumber);
          _verificationId = confirmationResult.verificationId;
          webConfirmationResult = confirmationResult;
        } else {
          await _auth.verifyPhoneNumber(
            forceResendingToken: 3,
            phoneNumber: phoneNumber,
            timeout: Duration(seconds: 20),
            verificationCompleted: verificationCompleted,
            verificationFailed: verificationFailed,
            codeSent: codeSent,
            codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
          );
        }
        success = true;
      } on FirebaseFunctionsException catch (error) {
        alert.show(
            text: error.message ?? error.details["message"], type: "error");
      } catch (error) {
        alert.show(text: error.toString(), type: "error");
      }
      loading = false;
      if (success) {
        section = 2;
      }
      if (mounted) setState(() {});
    }

    Future<void> _confirmCodeWeb() async {
      if (_smsController.text == "") {
        print("enter confirmation code");
        return;
      }
      if (webConfirmationResult?.verificationId != null) {
        try {
          final UserCredential credential =
              await webConfirmationResult!.confirm(_smsController.text);
          final User user = credential.user!;
          final User currentUser = _auth.currentUser!;
          assert(user.uid == currentUser.uid);
          _phoneNumberController.clear();
          _smsController.clear();
          section = 0;
          _closeKeyboard();
          if (mounted) setState(() {});
        } catch (error) {
          alert.show(text: locales.get("alert--sign-in-failed"), type: "error");
        }
      } else {
        // alert.show(text: locales.get("alert--sign-in-failed"), type: "error");
        alert.show(
            text: "Please input sms code received after verifying phone number",
            type: "error");
      }
    }

    /// Example code of how to sign in with phone.
    void _signInWithPhoneNumber() async {
      try {
        final AuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _smsController.text,
        );
        final User user = (await _auth.signInWithCredential(credential)).user!;
        final User currentUser = await _auth.currentUser!;
        assert(user.uid == currentUser.uid);
        _phoneNumberController.clear();
        _smsController.clear();
        section = 0;
        _closeKeyboard();
        if (mounted) setState(() {});
      } catch (error) {
        alert.show(text: locales.get("alert--sign-in-failed"), type: "error");
      }
    }

    /// Sign in with google function
    void _signInGoogle() async {
      try {
        loading = true;
        if (mounted) setState(() {});
        try {
          await _googleSignIn.disconnect(); // Disconnect previews account
        } catch (error) {
          print(error);
        }
        final GoogleSignInAccount googleUser =
            await (_googleSignIn.signIn() as FutureOr<GoogleSignInAccount>);
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final User? user = (await _auth.signInWithCredential(credential)).user;
        if (user != null) {
          print("Init");
        }
        loading = false;
      } catch (error) {
        print(error);
        loading = false;
      }
      if (mounted) setState(() {});
    }

    Future<void> _signInWithEmailAndLink() async {
//      _userEmail = _emailController.text;
      try {
        await _auth.sendSignInLinkToEmail(
          email: _userEmail,
          actionCodeSettings: ActionCodeSettings(
            url: 'PAGEURL',
            handleCodeInApp: true,
            iOSBundleId: "iOSBundleId",
            androidInstallApp: true,
            androidMinimumVersion: "1",
            androidPackageName: "ANDROIDBundleId",
          ),
        );
        alert.show(
          text: "Check your email",
          type: "success",
        );
      } catch (error) {
        print(error);
        alert.show(
          text: error.toString(),
          type: "error",
        );
      }
    }

    /// Acton button for general use
    Widget actionButton(
        {label: String, onPressed: VoidCallback, icon: Icons.navigate_next}) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label, style: TextStyle(color: Colors.white)),
        ),
      );
    }

    Widget authButton(provider) {
      String text = locales.get("page-auth--actions--sign-in");
      var icon = Icons.email;
      VoidCallback action = () {
        print("clicked: $provider");
      };
//      Color _iconColor = Material;
      switch (provider) {
        case "phone":
          text = locales.get("page-auth--actions--sign-in-mobile");
          icon = Icons.phone;
          action = () {
            section = 1;
            if (mounted) setState(() {});
          };
          break;
        case "google":
          text = locales.get("page-auth--actions--sign-in-google");
          icon = Icons.email;
          action = _signInGoogle;
          break;
        case "email":
          text = locales.get("page-auth--actions--sign-in-email");
          icon = Icons.email;
          action = _signInWithEmailAndLink;
      }
      return Container(
        // width: double.infinity,
        child: Padding(
          padding: EdgeInsets.only(top: 16),
          child: FloatingActionButton.extended(
            onPressed: action,
            label: Text(text.toUpperCase()),
            icon: Icon(icon),
          ),
        ),
      );
    }

//    final Widget svgIcon = Container(height: 10, width: 10);
    String backgroundImage =
        "https://images.unsplash.com/photo-1615406020658-6c4b805f1f30";
    Widget spacer = Container(width: 8, height: 8);
    Widget spacerLarge = Container(width: 16, height: 16);

    Widget home = AnimatedOpacity(
      opacity: section == 0 ? 1 : 0,
      duration: Duration(milliseconds: 300),
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
                          padding: EdgeInsets.all(16),
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
                                Container(
                                  width: double.infinity,
                                  child: Text(
                                    locales.get("page-auth--title"),
                                    style: textTheme.headline6,
                                    // textAlign: TextAlign.center,
                                  ),
                                ),
                                Container(height: 16),
                                Container(
                                  width: double.infinity,
                                  child: Text(
                                    locales.get("page-auth--description"),
                                    style: textTheme.subtitle1,
                                    // textAlign: TextAlign.center,
                                  ),
                                ),
                                Container(height: 16),
                                authButton("phone"),
                                // authButton("google"),
//                              authButton("email"),
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

    Widget baseContainer({children: List}) {
      return SizedBox.expand(
        child: AnimatedOpacity(
          opacity: section == 0 ? 0 : 1,
          duration: Duration(milliseconds: 300),
          child: Container(
//            color: Colors.red,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 stops: [0.0, 0.5, 1.0],
//                 colors: [
//                   Color.fromRGBO(0, 0, 0, 0.0),
//                   Color.fromRGBO(0, 0, 0, 0.2),
//                   Color.fromRGBO(0, 0, 0, 0.4),
//                 ],
//               ),
//             ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Wrap(
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buttonCancel = SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(Icons.close),
        style: ButtonStyle(
            backgroundColor:
                MaterialStateProperty.all<Color>(Colors.grey.shade800)),
        label: Text(locales.get("label--cancel")),
        onPressed: () {
          _phoneNumberController.clear();
          _smsController.clear();
          _closeKeyboard();
          section = 0;
          if (mounted) setState(() {});
        },
      ),
    );

    List<Widget> sectionsPhoneNumber = [
      Flex(
        direction: Axis.horizontal,
        children: <Widget>[
          CountryCodePicker(
            onChanged: (CountryCode countryCode) {
              areaCode = countryCode.toString();
            },
            // Initial selection and favorite can be one of code ('IT') OR DIAL_CODE('+39')
            initialSelection: "US",
            favorite: ["US"],
            // optional. Shows only country name and flag
            showCountryOnly: true,
            // optional. Shows only country name and flag when popup is closed.
            showOnlyCountryWhenClosed: false,
            // optional. aligns the flag and the Text left
            alignLeft: false,
            // dialogTextStyle: TextStyle(color: Colors.black),
            // hideSearch: true,
            // dialogTextStyle: TextStyle(color: Colors.black),
          ),
          spacer,
          Expanded(
            child: TextFormField(
              controller: _phoneNumberController,
              decoration: InputDecoration(
//                labelText: "Phone number",
                hintText: locales.get("label--phone-number"),
              ),
              keyboardType: TextInputType.number,
              // keyboardAppearance: Brightness.dark,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              onChanged: (value) {
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
      spacerLarge,
    ];

    if (_phoneNumberController.text.isNotEmpty) {
      sectionsPhoneNumber.add(
        actionButton(
          icon: Icons.send_rounded,
          label: locales.get("label--verify"),
          onPressed: () {
            _verifyPhoneNumber();
          },
        ),
      );
    }
    sectionsPhoneNumber.add(spacer);
    sectionsPhoneNumber.add(buttonCancel);

    Widget sectionPhoneNumber = baseContainer(children: sectionsPhoneNumber);

    List<Widget> sectionsPhoneVerification = [
      TextField(
        controller: _smsController,
        keyboardType: TextInputType.number,
        keyboardAppearance: Brightness.light,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly
        ],
        decoration: InputDecoration(
            hintText: locales.get("page-auth--input--verification-code")),
        maxLength: 6,
        onChanged: (value) {
          if (mounted) setState(() {});
        },
      ),
      spacerLarge,
    ];
//    if (_smsController.text.isEmpty) {
//      sectionsPhoneVerification.add(
//        actionButton(
////          label: locales.get("label--verify"),
//          label: "Didn't get the code",
//          onPressed: () {
//            // replace this
//            _verifyPhoneNumber();
//          },
//        ),
//      );
//    }
    if (_smsController.text.isNotEmpty) {
      sectionsPhoneVerification.add(
        actionButton(
          label: locales.get("page-auth--actions--sign-in-with-phone-number"),
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
      // backgroundColor: theme.backgroundColor,
      body: SizedBox.expand(
        child: Container(
          color: theme.backgroundColor,
          child: IndexedStack(
            index: section,
            children: <Widget>[
              home,
              sectionPhoneNumber,
              sectionPhoneVerification,
            ],
          ),
        ),
      ),
    );
  }
}
