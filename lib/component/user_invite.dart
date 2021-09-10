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
  }) : super(key: key);
  final User? user;
  final Map<String, dynamic>? data;
  final List<String>? roles;

  @override
  _UserInviteState createState() => _UserInviteState();
}

enum TypeOptions { phone, email }

class _UserInviteState extends State<UserInvite> {
  AppLocalizations? locales;
  bool? sending;
  String phoneNumber = "";
  String email = "";
  late String areaCode;
  String? finalPhoneNumber;
  String? roleSelect;
  dynamic resp;
  TextEditingController _textControllerPhone = TextEditingController();
  TextEditingController _textControllerEmail = TextEditingController();
  Color? backgroundColor;
  Function? onChange;
  bool flagRol = false;
  bool flagNumber = false;
  bool flagEmail = false;
  TypeOptions? _typeOption;

  @override
  void dispose() {
    _textControllerPhone.clear();
    _textControllerEmail.clear();
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
    backgroundColor = const Color(0xFF161A21);
    flagRol = false;
    flagNumber = false;
    roleSelect = null;
    _typeOption = TypeOptions.phone;
  }

  @override
  Widget build(BuildContext context) {
    bool canInvite = sending == false &&
        _typeOption != null &&
        roleSelect != null &&
        (flagEmail || flagNumber);

    AppLocalizations locales = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);
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
      alert.show(title: locales.get("notification--please-wait"), duration: 5);
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
            title: locales.get("notification--invitation-sent"),
            type: AlertTypes.success);
        Navigator.of(context).pop();
      } on FirebaseFunctionsException catch (error) {
        alert.show(
            title: error.message ?? error.details["message"], type: AlertTypes.critical);
      } catch (error) {
        alert.show(title: error.toString(), type: AlertTypes.critical);
      }
      sending = false;
      if (mounted) setState(() {});
    }

    void validateInvitation() async {
      if (!canInvite) {
        alert.show(title: "incomplete data", type: AlertTypes.critical);
      }
      if (_typeOption == TypeOptions.phone) {
        await _sendInvitation(
            type: "phoneNumber", contact: finalPhoneNumber, role: roleSelect);
      } else {
        await _sendInvitation(type: "email", contact: email, role: roleSelect);
      }
    }

    /// Invite user using a phone number.
    Widget _inviteUserPhone() {
      return Row(
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
              controller: _textControllerPhone,
              decoration: InputDecoration(
                hintText: locales.get("label--enter-phone-number"),
              ),
              maxLines: 1,
              maxLength: 12,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              keyboardType: TextInputType.number,
              enableSuggestions: false,
              onChanged: (text) {
                phoneNumber = text;
                finalPhoneNumber = areaCode + phoneNumber;
                if (phoneNumber.length > 5) {
                  flagNumber = true;
                } else {
                  flagNumber = false;
                }
                if (mounted) setState(() {});
              },
              // Disable blank space from input.
              inputFormatters: [
                FilteringTextInputFormatter.deny(" ", replacementString: ""),
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ),
          Container(
            width: 16,
          ),
        ],
      );
    }

    /// Invite user using an e-mail.
    Widget _inviteUserEmail() {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          enableSuggestions: false,
          controller: _textControllerEmail,
          decoration: InputDecoration(
            hintText: locales.get("label--enter-an-email"),
            prefixIcon: Icon(Icons.mail),
          ),
          maxLines: 1,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          maxLength: 100,
          keyboardType: TextInputType.emailAddress,
          onChanged: (text) {
            email = text;
            flagEmail = email.length > 5;
            if (mounted) setState(() {});
          },
          // Disable blank space from input.
          inputFormatters: [
            FilteringTextInputFormatter.deny(" ", replacementString: ""),
            FilteringTextInputFormatter.deny("+", replacementString: ""),
            FilteringTextInputFormatter.singleLineFormatter,
          ],
        ),
      );
    }

    Widget selectedTypeWidget = _typeOption == TypeOptions.phone
        ? _inviteUserPhone()
        : _inviteUserEmail();

    Widget typeSelector = Row(
      children: <Widget>[
        Expanded(
          child: RadioListTile<TypeOptions>(
            contentPadding: EdgeInsets.only(left: 8),
            title: Text(locales.get("label--phone-number")),
            value: TypeOptions.phone,
            groupValue: _typeOption,
            onChanged: (TypeOptions? value) {
              _typeOption = value;
              if (mounted) setState(() {});
            },
          ),
        ),
        Expanded(
          child: RadioListTile<TypeOptions>(
            contentPadding: EdgeInsets.only(right: 8),
            title: Text(locales.get("label--email")),
            value: TypeOptions.email,
            groupValue: _typeOption,
            onChanged: (TypeOptions? value) {
              _typeOption = value;
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        primary: false,
        automaticallyImplyLeading: false,
        title: Text(locales.get("user-invite--title")),
        leading: Icon(Icons.person),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: canInvite
          ? FloatingActionButton.extended(
              icon: Icon(Icons.send),
              label: Text(
                locales.get("label--send-invitation"),
                style: TextStyle(color: Colors.white),
              ),
              onPressed: validateInvitation,
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            RoleSelector(
              roles: widget.roles,
              onChange: (value) {
                if (value != null) {
                  roleSelect = value;
                  flagRol = true;
                }
                if (mounted) setState(() {});
              },
            ),
            typeSelector,
            Container(height: 16),
            selectedTypeWidget,
          ],
        ),
      ),
    );
  }
}
