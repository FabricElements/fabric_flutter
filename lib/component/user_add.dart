import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../serialized/add_user_data.dart';
import '../state/state_alert.dart';
import 'input_data.dart';
import 'role_selector.dart';

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
    required this.onAdd,
    required this.uid,
    this.email = true,
    this.phone = true,
    this.username = true,
    this.name = true,
    required this.onChanged,
  }) : super(key: key);
  final Map<String, dynamic>? data;
  final List<String>? roles;
  final Function(AddUserData data) onAdd;
  final dynamic uid;
  final bool email;
  final bool phone;
  final bool username;
  final bool name;
  final Function onChanged;

  @override
  State<UserAdd> createState() => _UserAddState();
}

class _UserAddState extends State<UserAdd> {
  late bool sending;
  Color? backgroundColor;
  Function? onChange;
  late AddUserData data;

  @override
  void initState() {
    data = AddUserData(uid: widget.uid, data: widget.data);
    sending = false;
    backgroundColor = const Color(0xFF161A21);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool canInvite = sending == false &&
        data.role != null &&
        ((data.email ?? data.phone ?? '').length > 4) &&
        (widget.username &&
                (data.username != null && data.username!.isNotEmpty) ||
            !widget.username);
    final locales = AppLocalizations.of(context)!;
    final alert = Provider.of<StateAlert>(context, listen: false);
    const spacer = SizedBox(height: 8, width: 8);

    /// Sends user invite to firebase function with the necessary information when inviting a user.
    ///
    /// [type] Whether it is an e-mail or phone number.
    /// [contact] The e-mail or phone number.
    addUser() async {
      sending = true;
      if (mounted) setState(() {});
      assert(data.role != null, 'You must select a user role');
      assert(data.username != null || data.email != null || data.phone != null,
          'username, email or phone must not be null');

      alert.show(AlertData(
        body: locales.get('notification--please-wait'),
        duration: 5,
      ));

      try {
        await widget.onAdd(data);
        alert.show(AlertData(
          body: locales.get('notification--added'),
          type: AlertType.success,
          duration: 3,
        ));
        Navigator.pop(context, 'send-invitation');
        await widget.onChanged();
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
      await addUser();
    }

    Widget phoneInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        label: locales.get('label--phone-number'),
        isExpanded: true,
        value: data.phone,
        type: InputDataType.phone,
        onChanged: (value) {
          data.phone = value;
          if (mounted) setState(() {});
        },
      ),
    );
    Widget emailInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        label: locales.get('label--email'),
        isExpanded: true,
        value: data.email,
        type: InputDataType.email,
        onChanged: (value) {
          data.email = value;
          if (mounted) setState(() {});
        },
      ),
    );

    Widget usernameInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        label: locales.get('label--username'),
        isExpanded: true,
        value: data.username,
        type: InputDataType.string,
        onChanged: (value) {
          data.username = value;
          if (mounted) setState(() {});
        },
      ),
    );

    Widget firstNameInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        label: locales.get('label--first-name'),
        isExpanded: true,
        value: data.firstName,
        type: InputDataType.string,
        onChanged: (value) {
          data.firstName = value;
          if (mounted) setState(() {});
        },
      ),
    );
    Widget lastNameInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        label: locales.get('label--last-name'),
        isExpanded: true,
        value: data.lastName,
        type: InputDataType.string,
        onChanged: (value) {
          data.lastName = value;
          if (mounted) setState(() {});
        },
      ),
    );

    List<Widget> inviteWidgets = [
      RoleSelector(
        roles: widget.roles,
        onChange: (value) {
          data.role = value;
          if (mounted) setState(() {});
        },
      ),
    ];

    if (widget.email) {
      inviteWidgets.addAll([
        spacer,
        emailInput,
      ]);
    }
    if (widget.phone) {
      inviteWidgets.addAll([
        spacer,
        phoneInput,
      ]);
    }

    if (widget.username) {
      inviteWidgets.addAll([
        spacer,
        usernameInput,
      ]);
    }
    if (widget.name) {
      inviteWidgets.addAll([
        spacer,
        firstNameInput,
        spacer,
        lastNameInput,
      ]);
    }

    inviteWidgets.addAll([
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: Text(locales.get('label--cancel')),
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
    ]);

    return SimpleDialog(
      title: Text(locales.get('user-invite--title')),
      contentPadding: const EdgeInsets.all(20),
      children: inviteWidgets,
    );
  }
}
