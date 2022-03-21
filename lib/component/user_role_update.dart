import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../helper/alert_helper.dart';
import '../helper/app_localizations_delegate.dart';
import 'role_selector.dart';

/// Updates User Role
///
/// [user] Firebase User object with user's information
/// [data] Object with necessary information such as 'organization'
/// ```dart
/// UserRoleUpdate(
///   'info': {
///     'organization': 'organization-id',
///   }
/// );
/// ```
class UserRoleUpdate extends StatefulWidget {
  const UserRoleUpdate({
    Key? key,
    this.roles,
    this.data,
    required this.uid,
    required this.name,
    this.selected,
  }) : super(key: key);
  final Map<String, dynamic>? data;
  final List<String>? roles;
  final String uid;
  final String name;
  final String? selected;

  @override
  _UserRoleUpdateState createState() => _UserRoleUpdateState();
}

class _UserRoleUpdateState extends State<UserRoleUpdate> {
  AppLocalizations? locales;
  bool? sending;
  String? roleSelect;
  dynamic resp;
  Color? backgroundColor;
  Function? onChange;
  bool flagRol = false;

  @override
  void dispose() {
    roleSelect = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    sending = false;
    resp = null;
    backgroundColor = const Color(0xFF161A21);
    flagRol = false;
    roleSelect = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    bool canInvite = sending == false && roleSelect != null;
    AppLocalizations locales = AppLocalizations.of(context)!;
    AlertHelper alert = AlertHelper(
      context: context,
      mounted: mounted,
    );

    /// Sends user invite to firebase function with the necessary information when inviting a user.
    ///
    /// [type] Whether it is an e-mail or phone number.
    /// [contact] The e-mail or phone number.
    updateUserRole() async {
      if (!canInvite) {
        alert.show(
          title: 'incomplete data',
          type: AlertType.critical,
          duration: 5,
        );
        return;
      }
      sending = true;
      if (mounted) setState(() {});
      alert.show(body: locales.get('notification--please-wait'), duration: 5);
      Map<String, dynamic> data = {
        'role': roleSelect,
        'uid': widget.uid,
      };
      if (widget.data != null) {
        data.addAll(widget.data!);
      }
      try {
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('user-actions-updateRole');
        await callable.call(data);
        alert.show(
          body: locales.get('notification--user-role-updated'),
          type: AlertType.success,
          duration: 3,
        );
        Navigator.of(context).pop();
      } on FirebaseFunctionsException catch (error) {
        alert.show(
          body: error.message ?? error.details['message'],
          type: AlertType.critical,
          duration: 5,
        );
      } catch (error) {
        alert.show(
          body: error.toString(),
          type: AlertType.critical,
          duration: 5,
        );
      }
      sending = false;
      if (mounted) setState(() {});
    }

    return SimpleDialog(
      title:
          Text(locales.get('user-role-update--title', {'name': widget.name})),
      children: [
        RoleSelector(
          asList: true,
          roles: widget.roles,
          onChange: (value) {
            if (value != null) {
              roleSelect = value;
              flagRol = true;
            }
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: Text(
            locales.get('label--update'),
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: canInvite ? updateUserRole : null,
        )
      ],
      contentPadding: const EdgeInsets.all(20),
    );
  }
}
