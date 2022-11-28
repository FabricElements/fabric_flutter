import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../serialized/user_data.dart';
import '../state/state_alert.dart';
import 'input_data.dart';

/// Sends invitation to a new user
///
/// [roles] Optional array of roles
/// ```dart
/// UserAddUpdate(
/// );
/// ```
class UserAddUpdate extends StatefulWidget {
  const UserAddUpdate({
    Key? key,
    this.roles,
    required this.onConfirm,
    this.email = true,
    this.phone = true,
    this.role = true,
    this.username = true,
    this.name = true,
    this.password = false,
    required this.onChanged,
    this.user,
    this.group,
    this.groupId,
  }) : super(key: key);
  final List<String>? roles;
  final Function(UserData data, {dynamic group, dynamic groupId}) onConfirm;
  final bool email;
  final bool phone;
  final bool username;
  final bool name;
  final bool role;
  final bool password;
  final Function onChanged;
  final UserData? user;
  final dynamic group;
  final dynamic groupId;

  @override
  State<UserAddUpdate> createState() => _UserAddUpdateState();
}

class _UserAddUpdateState extends State<UserAddUpdate> {
  late bool sending;
  Color? backgroundColor;
  Function? onChange;
  late UserData data;

  @override
  void initState() {
    data = widget.user ?? UserData(id: widget.user?.id);
    sending = false;
    backgroundColor = const Color(0xFF161A21);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool canInvite = sending == false &&
        ((data.email ?? data.phone ?? '').length > 4) &&
        (widget.username &&
                (data.username != null && data.username!.isNotEmpty) ||
            !widget.username);
    final locales = AppLocalizations.of(context)!;
    final alert = Provider.of<StateAlert>(context, listen: false);
    const spacer = SizedBox(height: 16, width: 16);
    final title = locales
        .get(data.id == null ? 'label--add-label' : 'label--update-label', {
      'label': locales.get('label--user'),
    });

    /// Sends user invite to firebase function with the necessary information when inviting a user.
    ///
    /// [type] Whether it is an e-mail or phone number.
    /// [contact] The e-mail or phone number.
    addUser() async {
      sending = true;
      if (mounted) setState(() {});
      assert(data.role.isNotEmpty, 'You must select a user role');
      assert(data.username != null || data.email != null || data.phone != null,
          'username, email or phone must not be null');
      try {
        await widget.onConfirm(data,
            group: widget.group, groupId: widget.groupId);
        alert
            .show(AlertData(
          clear: true,
          brightness: Brightness.dark,
          body: locales.get('notification--added'),
          type: AlertType.success,
          duration: 3,
        ))
            .then((value) {
          Navigator.pop(context);
        });
        await widget.onChanged();
      } on FirebaseFunctionsException catch (error) {
        alert.show(AlertData(
          clear: true,
          brightness: Brightness.dark,
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
        ));
      } catch (error) {
        alert.show(AlertData(
          clear: true,
          brightness: Brightness.dark,
          body: error.toString(),
          type: AlertType.critical,
        ));
      }
      sending = false;
      if (mounted) setState(() {});
    }

    void validateInvitation() async {
      if (!canInvite) {
        alert.show(AlertData(
          clear: true,
          brightness: Brightness.dark,
          title: 'incomplete data',
          type: AlertType.critical,
        ));
      }
      await addUser();
    }

    Widget phoneInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        icon: Icons.phone,
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
        icon: Icons.email,
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
        icon: Icons.alternate_email,
        label: locales.get('label--username'),
        isExpanded: true,
        value: data.username,
        type: InputDataType.string,
        maxLength: 20,
        onChanged: (value) {
          data.username = value;
          if (mounted) setState(() {});
        },
      ),
    );

    Widget firstNameInput = InputData(
      label: locales.get('label--first-name'),
      isExpanded: true,
      value: data.firstName,
      type: InputDataType.string,
      onChanged: (value) {
        data.firstName = value;
        if (mounted) setState(() {});
      },
      maxLength: 20,
    );
    Widget lastNameInput = InputData(
      label: locales.get('label--last-name'),
      isExpanded: true,
      value: data.lastName,
      type: InputDataType.string,
      onChanged: (value) {
        data.lastName = value;
        if (mounted) setState(() {});
      },
      maxLength: 20,
    );

    Widget passwordInput = InputData(
      icon: Icons.lock,
      label: locales.get('label--password'),
      isExpanded: true,
      value: data.password,
      type: InputDataType.secret,
      obscureText: true,
      onChanged: (value) {
        data.password = value;
        if (mounted) setState(() {});
      },
      maxLength: 20,
    );

    List<String> roles = widget.roles ?? ['user', 'admin'];
    List<Widget> inviteWidgets = [];
    if (widget.role) {
      inviteWidgets.addAll([
        InputData(
          icon: Icons.security,
          label: locales.get('label--role'),
          value: data.role,
          type: InputDataType.dropdown,
          options: List.generate(roles.length, (index) {
            final item = roles[index];
            return ButtonOptions(
              value: item,
              label: locales.get('label--$item'),
            );
          }),
          onChanged: (value) {
            data.role = value ?? roles.first;
            if (mounted) setState(() {});
          },
        ),
        spacer,
        spacer,
      ]);
    }
    if (widget.name) {
      inviteWidgets.addAll([
        Row(
          children: [
            Expanded(child: firstNameInput),
            spacer,
            Expanded(child: lastNameInput),
          ],
        ),
        spacer,
      ]);
    }
    if (widget.email) {
      inviteWidgets.addAll([
        emailInput,
        spacer,
      ]);
    }
    if (widget.phone) {
      inviteWidgets.addAll([
        phoneInput,
        spacer,
      ]);
    }
    if (widget.username) {
      inviteWidgets.addAll([
        usernameInput,
        spacer,
      ]);
    }
    if (widget.password) {
      inviteWidgets.addAll([
        passwordInput,
        spacer,
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
              label: Text(title),
              onPressed: canInvite ? validateInvitation : null,
            ),
          ],
        ),
      )
    ]);

    return SimpleDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.all(20),
      children: inviteWidgets,
    );
  }
}
