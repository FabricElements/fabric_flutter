import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../state/state_alert.dart';
import '../state/state_user.dart';
import 'input_data.dart';
import 'role_selector.dart';

enum TypeOptions { phone, email }

/// Sends invitation to a new user
///
/// [roles] Optional array of roles
/// [data] Object with necessary information such as 'organization' data
/// ```dart
/// UserAdd(
///   'data': {
///     'organization': 'organization-id',
///   }
/// );
/// ```
class UserAdd extends StatefulWidget {
  const UserAdd({
    Key? key,
    this.roles,
    this.data,
  }) : super(key: key);
  final Map<String, dynamic>? data;
  final List<String>? roles;

  @override
  State<UserAdd> createState() => _UserAddState();
}

class _UserAddState extends State<UserAdd> {
  AppLocalizations? locales;
  bool? sending;
  String phoneNumber = '';
  String email = '';
  String? roleSelect;
  dynamic resp;
  final _textControllerPhone = TextEditingController();
  final _textControllerEmail = TextEditingController();
  Color? backgroundColor;
  Function? onChange;
  late TypeOptions _typeOption;

  @override
  void dispose() {
    _textControllerPhone.clear();
    _textControllerEmail.clear();
    roleSelect = null;
    super.dispose();
  }

  @override
  void initState() {
    phoneNumber = '';
    email = '';
    sending = false;
    resp = null;
    backgroundColor = const Color(0xFF161A21);
    roleSelect = null;
    _typeOption = TypeOptions.phone;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final stateUser = Provider.of<StateUser>(context);
    bool canInvite = sending == false &&
        roleSelect != null &&
        (email.length > 4 || phoneNumber.length >= 8);

    AppLocalizations locales = AppLocalizations.of(context)!;
    // ThemeData theme = Theme.of(context);
    final alert = Provider.of<StateAlert>(context, listen: false);

    /// Sends user invite to firebase function with the necessary information when inviting a user.
    ///
    /// [type] Whether it is an e-mail or phone number.
    /// [contact] The e-mail or phone number.
    _sendInvitation(
        {required String type, String? contact, String? role}) async {
      if (contact == null) {
        if (kDebugMode) print('Define the contact information before sending');
        return;
      }
      sending = true;
      if (mounted) setState(() {});
      alert.show(AlertData(
        body: locales.get('notification--please-wait'),
        duration: 5,
      ));
      Map<String, dynamic> data = {};
      if (role != null) {
        data.addAll({
          'role': role,
        });
      }
      data.addAll({
        'uid': stateUser.id,
      });
      if (widget.data != null) {
        data.addAll(widget.data!);
      }
      // Update object with email or phone depending on the type.
      if (type == 'email') {
        data.addAll({'email': contact});
      } else {
        data.addAll({'phoneNumber': contact});
      }
      try {
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('user-actions-invite');
        await callable.call(data);
        alert.show(AlertData(
          body: locales.get('notification--added'),
          type: AlertType.success,
          duration: 3,
        ));
        Navigator.pop(context, 'send-invitation');
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
        ));
      } catch (error) {
        alert.show(AlertData(body: error.toString(), type: AlertType.critical));
      }
      sending = false;
      if (mounted) setState(() {});
    }

    void validateInvitation() async {
      if (!canInvite) {
        alert.show(AlertData(
          title: 'incomplete data',
          type: AlertType.critical,
        ));
      }
      if (_typeOption == TypeOptions.phone) {
        await _sendInvitation(
          type: 'phoneNumber',
          contact: phoneNumber,
          role: roleSelect,
        );
      } else {
        await _sendInvitation(
          type: 'email',
          contact: email,
          role: roleSelect,
        );
      }
    }

    /// Invite user using a phone number or email
    Widget selectedTypeWidget = _typeOption == TypeOptions.phone
        ? InputData(
            isExpanded: true,
            value: phoneNumber,
            type: InputDataType.phone,
            onChanged: (value) {
              phoneNumber = value;
              if (mounted) setState(() {});
            },
          )
        : InputData(
            isExpanded: true,
            value: email,
            type: InputDataType.email,
            onChanged: (value) {
              email = value;
              if (mounted) setState(() {});
            },
          );

    Widget typeSelector = Row(
      children: <Widget>[
        Expanded(
          child: RadioListTile<TypeOptions>(
            contentPadding: const EdgeInsets.only(left: 8),
            title: Text(locales.get('label--phone-number')),
            value: TypeOptions.phone,
            groupValue: _typeOption,
            onChanged: (TypeOptions? value) {
              _typeOption = value!;
              email = '';
              phoneNumber = '';
              if (mounted) setState(() {});
            },
          ),
        ),
        Expanded(
          child: RadioListTile<TypeOptions>(
            contentPadding: const EdgeInsets.only(right: 8),
            title: Text(locales.get('label--email')),
            value: TypeOptions.email,
            groupValue: _typeOption,
            onChanged: (TypeOptions? value) {
              _typeOption = value!;
              email = '';
              phoneNumber = '';
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );

    List<Widget> inviteWidgets = [
      RoleSelector(
        roles: widget.roles,
        onChange: (value) {
          if (value != null) {
            roleSelect = value;
          }
          if (mounted) setState(() {});
        },
      ),
      typeSelector,
      Container(height: 16),
      SizedBox(
        width: double.maxFinite,
        child: selectedTypeWidget,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: Text(
                locales.get('label--cancel'),
              ),
              onPressed: () {
                Navigator.pop(context, 'cancel');
              },
              style: TextButton.styleFrom(primary: Colors.deepOrange),
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: Text(
                locales.get('label--add-label', {
                  'label': locales.get('label--user'),
                }),
              ),
              onPressed: canInvite ? validateInvitation : null,
            ),
          ],
        ),
      )
    ];

    return SimpleDialog(
      title: Text(locales.get('user-invite--title')),
      children: inviteWidgets,
      contentPadding: const EdgeInsets.all(20),
    );
  }
}
