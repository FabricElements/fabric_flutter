import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helper/alert.dart';
import '../helper/app_localizations_delegate.dart';
import 'role_selector.dart';

/// Sends invitation to a new user
///
/// [user] Firebase User object with user's information
/// [data] Object with necessary information such as "organization"
/// ```dart
/// Invitation(
///   "user": user-data-object,
///   "info": {
///     "organization": "organization-id",
///   }
/// );
/// ```
class UserInvite extends StatefulWidget {
  UserInvite({
    Key? key,
    this.user,
    this.roles,
    this.data,
    this.showEmail = false,
    this.showPhone = false,
  }) : super(key: key);
  final User? user;
  final Map<String, dynamic>? data;
  final bool showEmail;
  final bool showPhone;
  final List<String>? roles;

  @override
  _UserInviteState createState() => _UserInviteState();
}

class _UserInviteState extends State<UserInvite> {
  AppLocalizations? locales;
  bool? sending;
  late String phoneNumber;
  String? email;
  late String areaCode;
  String? finalPhoneNumber;
  String? roleSelect;
  dynamic resp;
  TextEditingController? _textController;
  Color? backgroundColor;
  Function? onChange;
  late bool flagRol;
  late bool flagNumber;

  @override
  void dispose() {
    _textController!.clear();
    flagRol = false;
    flagNumber = false;
    roleSelect = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    phoneNumber = "";
    email = "";
    areaCode = "+1";
    finalPhoneNumber = "";
    sending = false;
    resp = null;
    _textController = TextEditingController();
    backgroundColor = const Color(0xFF161A21);
    flagRol = false;
    flagNumber = false;
    roleSelect = null;
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations locales = AppLocalizations.of(context)!;
    Alert alert = Alert(
      context: context,
      mounted: mounted,
    );

    /// Sends user invite to firebase function with the necessary information when inviting a user.
    ///
    /// [type] Whether it is an e-mail or phone number.
    /// [contact] The e-mail or phone number.
    _sendInvitation(
        {required String type, String? contact, String? role}) async {
      if (contact == null) {
        print("Define the contact information before sending");
        return;
      }
      sending = true;
      if (mounted) setState(() {});
      Map<String, dynamic> data = {};
      if (role != null) {
        data.addAll({
          "role": role,
        });
      }
      if (widget.user != null) {
        data.addAll({
          "uid": widget.user?.uid ?? null,
          "name": widget.user?.displayName ?? null,
          "avatar": widget.user?.photoURL ?? null,
        });
      }

      if (widget.data != null) {
        data.addAll(widget.data!);
      }
      // Update object with email or phone depending on the type.
      if (type == "email") {
        data.addAll({"email": contact});
      } else {
        data.addAll({"phoneNumber": contact});
      }
      try {
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable("user-actions-invite");
        await callable.call(data);
        alert.show(
            text: locales.get("notification--invitation-sent"),
            type: "success");
        Navigator.of(context).pop();
      } on FirebaseFunctionsException catch (error) {
        alert.show(
            text: error.message ?? error.details["message"], type: "error");
      } catch (error) {
        alert.show(text: error.toString(), type: "error");
      }
      sending = false;
      if (mounted) setState(() {});
    }

    void validateInvitation() async {
      if (phoneNumber.length < 5) {
        alert.show(text: locales.get("alert--invalid-number"), type: "error");
      } else {
        _textController!.clear();
        if (flagRol && flagNumber) {
          await _sendInvitation(
              type: "phoneNumber", contact: finalPhoneNumber, role: roleSelect);
        }
      }
    }

    /// Invite user using a phone number.
    Widget _inviteUserPhone() {
      return Column(
        children: <Widget>[
          RoleSelector(
            roles: widget.roles,
            onChange: (value) {
              if (value != null) {
                roleSelect = value;
                flagRol = true;
              }
              if (mounted) {
                setState(() {});
              }
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CountryCodePicker(
                onChanged: (CountryCode countryCode) {
                  areaCode = countryCode.toString();
                },
                // Initial selection and favorite can be one of code ('IT') OR dial_code('+39')
                initialSelection: "US",
                favorite: ["US"],
                // optional. Shows only country name and flag
                showCountryOnly: false,
                // optional. Shows only country name and flag when popup is closed.
                showOnlyCountryWhenClosed: false,
                // optional. aligns the flag and the Text left
                alignLeft: false,
              ),
              Expanded(
                child: TextField(
                  autofocus: true,
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: locales.get("label--enter-phone-number"),
                  ),
                  maxLines: 1,
                  keyboardType: TextInputType.number,
                  onChanged: (text) {
                    phoneNumber = text;
                    finalPhoneNumber = areaCode + phoneNumber;
                    if (phoneNumber.length > 5) {
                      flagNumber = true;
                    } else {
                      flagNumber = false;
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  // Disable blank space from input.
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(" ",
                        replacementString: ""),
                  ],
                ),
              ),
              Container(
                width: 16,
              ),
            ],
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 32, top: 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.send),
                label: Text(
                  locales.get("label--send-invitation"),
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: flagRol && flagNumber ? validateInvitation : null,
              ),
            ),
          ),
        ],
      );
    }

    /// Invite user using an e-mail.
    Widget _inviteUserEmail() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 8, left: 8, top: 8),
            child: Icon(Icons.mail, size: 32.0),
          ),
          Expanded(
            child: TextField(
              autofocus: true,
              controller: _textController,
              decoration: InputDecoration(
                hintText: locales.get("label--enter-an-email"),
              ),
              maxLines: 1,
              maxLength: 100,
              keyboardType: TextInputType.emailAddress,
              onChanged: (text) {
                email = text;
              },
              // Disable blank space from input.
              inputFormatters: [
                FilteringTextInputFormatter.deny(" ", replacementString: ""),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () async {
              RegExp emailRegExp = new RegExp(
                  r"\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b");
              // If there is no match, show an error.
              if (!emailRegExp.hasMatch(email!)) {
                alert.show(
                    text: locales.get("alert--invalid-email"), type: "error");
              } else {
                sending = true;
                if (mounted) setState(() {});
                await _sendInvitation(type: "email", contact: email);
                _textController!.clear();
              }
            },
          ),
        ],
      );
    }

    List<Widget> _tabs = [];
    List<Widget> _tabsBody = [];

    if (widget.showPhone) {
      _tabs.add(Tab(text: locales.get("label--phone-number")));
      _tabsBody.add(_inviteUserPhone());
    }

    if (widget.showEmail) {
      _tabs.add(Tab(text: locales.get("label--email")));
      _tabsBody.add(_inviteUserEmail());
    }

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(
              child: TabBarView(
                children: _tabsBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
