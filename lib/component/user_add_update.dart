import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/input_validation.dart';
import '../helper/options.dart';
import '../helper/regex_helper.dart';
import '../helper/utils.dart';
import '../serialized/user_data.dart';
import '../state/state_alert.dart';
import 'content_container.dart';
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
    super.key,
    this.roles = const ['user', 'admin'],
    required this.onConfirm,
    this.email = false,
    this.phone = false,
    this.role = false,
    this.multipleRoles = false,
    this.username = false,
    this.name = false,
    this.password = false,
    required this.onChanged,
    this.user,
    this.group,
    this.groups,
    this.successMessage = 'notification--request-success',
    this.size = ContentContainerSize.medium,
  });

  /// Array of roles
  final List<String> roles;

  /// Function to call when the user is added or updated
  final Function(UserData data, {String? group}) onConfirm;

  /// Allow email to be entered
  final bool email;

  /// Allow phone number to be entered
  final bool phone;

  /// Allow username to be entered
  final bool username;

  /// Allow name to be entered
  final bool name;

  /// Allow single role to be selected
  final bool role;

  /// Allow multiple roles to be selected
  final bool multipleRoles;

  /// Allow password to be entered
  final bool password;

  /// Function to call when the user is added or updated
  final Function onChanged;

  /// User data to update
  final UserData? user;

  /// Group id
  final String? group;

  /// Success message to display
  final String successMessage;

  /// Groups roles used for dropdown options
  /// {'groupName':['admin','agent']}
  /// updates the UserData.roles['groupName'] = 'group role'
  final Map<String, List<String>>? groups;

  /// Size of the container
  final ContentContainerSize size;

  @override
  State<UserAddUpdate> createState() => _UserAddUpdateState();
}

class _UserAddUpdateState extends State<UserAddUpdate> {
  late bool sending;
  Color? backgroundColor;
  Function? onChange;
  late UserData data;
  String? error;

  @override
  void initState() {
    /// Set default user data
    data = widget.user ?? UserData(id: widget.user?.id);

    /// If the role assigned doesn't match the options, set the first role from the list
    if (!widget.roles.contains(data.role)) {
      data.role = widget.roles.first;
    }
    sending = false;
    backgroundColor = const Color(0xFF161A21);
    error = null;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final locales = AppLocalizations.of(context);
    final alert = Provider.of<StateAlert>(context, listen: false);
    bool canCall = sending == false;
    bool validPhone = data.phone != null && data.phone!.isNotEmpty;
    bool validEmail = data.email != null && data.email!.isNotEmpty;
    bool validUsername = data.username != null && data.username!.isNotEmpty;
    canCall = canCall && (validPhone || validEmail || validUsername);
    if (widget.name) {
      canCall = canCall &&
          data.firstName != null &&
          data.firstName!.length > 1 &&
          data.lastName != null &&
          data.lastName!.length > 1;
    }
    if (widget.password) {
      canCall = canCall && data.password != null && data.password!.isNotEmpty;
      bool newPasswordOk = RegexHelper.password.hasMatch(data.password ?? '');
      canCall = canCall && newPasswordOk;
    }
    const spacer = SizedBox(height: 16, width: 16);
    String title = locales
        .get(data.id == null ? 'label--add-label' : 'label--update-label', {
      'label': locales.get('label--user'),
    });
    String actionLabel = title;
    // Get name for title
    String? nameForTitle;
    if (data.firstName != null || data.lastName != null) {
      nameForTitle = Utils.nameFromParts(
        firstName: data.firstName,
        lastName: data.lastName,
      );
    }
    nameForTitle ??=
        data.firstName ?? data.username ?? data.phone ?? data.email ?? data.id;
    if (nameForTitle != null) {
      title += ': $nameForTitle';
    }

    /// Sends user invite to firebase function with the necessary information when inviting a user.
    ///
    /// [type] Whether it is an e-mail or phone number.
    /// [contact] The e-mail or phone number.
    addUser() async {
      sending = true;
      error = null;
      if (mounted) setState(() {});
      try {
        assert(data.role.isNotEmpty, 'You must select a user role');
        assert(
            data.username != null || data.email != null || data.phone != null,
            'username, email or phone must not be null');
        await widget.onConfirm(data, group: widget.group);
        alert
            .show(AlertData(
          clear: true,
          body: locales.get(widget.successMessage),
          type: AlertType.success,
          duration: 3,
        ))
            .then((value) {
          Navigator.pop(context);
        });
        await widget.onChanged();
      } on FirebaseFunctionsException catch (e) {
        error = e.message ?? e.details['message'];
      } catch (e) {
        error = e.toString();
      }
      sending = false;
      if (mounted) setState(() {});
    }

    Widget phoneInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        prefixIcon: const Icon(Icons.phone),
        label: locales.get('label--phone-number'),
        isExpanded: true,
        value: data.phone,
        type: InputDataType.phone,
        onChanged: (value) {
          error = null;
          data.phone = value;
          if (mounted) setState(() {});
        },
      ),
    );
    Widget emailInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        prefixIcon: const Icon(Icons.email),
        label: locales.get('label--email'),
        isExpanded: true,
        value: data.email,
        type: InputDataType.email,
        onChanged: (value) {
          error = null;
          data.email = value;
          if (mounted) setState(() {});
        },
      ),
    );

    Widget usernameInput = SizedBox(
      width: double.maxFinite,
      child: InputData(
        prefixIcon: const Icon(Icons.alternate_email),
        label: locales.get('label--username'),
        isExpanded: true,
        value: data.username,
        type: InputDataType.string,
        maxLength: 20,
        onChanged: (value) {
          error = null;
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
        error = null;
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
        error = null;
        data.lastName = value;
        if (mounted) setState(() {});
      },
      maxLength: 20,
    );
    final inputValidation = InputValidation(locales: locales);

    Widget passwordInput = InputData(
      prefixIcon: const Icon(Icons.lock),
      label: locales.get('label--password'),
      isExpanded: true,
      value: data.password,
      type: InputDataType.secret,
      validator: inputValidation.validatePassword,
      onChanged: (value) {
        error = null;
        data.password = value;
        if (mounted) setState(() {});
      },
      maxLength: 20,
    );

    List<Widget> inviteWidgets = [
      spacer,
    ];
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
    if (widget.role) {
      inviteWidgets.addAll([
        InputData(
          label: locales.get('label--role'),
          value: data.role,
          type: InputDataType.dropdown,
          prefixIcon: const Icon(Icons.security),
          options: List.generate(widget.roles.length, (index) {
            final item = widget.roles[index];
            return ButtonOptions(
              value: item,
              label: locales.get('label--$item'),
            );
          }),
          onChanged: (value) {
            error = null;
            data.role = value ?? widget.roles.first;
            if (mounted) setState(() {});
          },
        ),
        spacer,
        spacer,
      ]);
    }

    /// Manage roles by group
    if (widget.groups != null) {
      inviteWidgets.addAll([
        const Divider(),
        ListTile(
          title: Text(locales.get('label--roles-by-group')),
          leading: const Icon(Icons.group),
        ),
        spacer,
      ]);
      final groupsRolesItems = widget.groups!.entries.toList();
      for (int i = 0; i < groupsRolesItems.length; i++) {
        final item = groupsRolesItems[i];
        final groupsRoles = item.value;
        inviteWidgets.addAll([
          InputData(
            label: locales.get('label--role-for-label',
                {'label': locales.get('label--${item.key}')}),
            value: data.groups[item.key],
            type: InputDataType.dropdown,
            options: List.generate(groupsRoles.length, (index) {
              final item = groupsRoles[index];
              String labelKey = 'label--$item';
              String label = locales.get(labelKey);
              // if the label is not found, use the item as the label
              if (label == labelKey) {
                label = item[0].toUpperCase() + item.substring(1);
              }
              return ButtonOptions(
                value: item,
                label: label,
              );
            }),
            onChanged: (value) {
              error = null;
              Map<String, String> newRoles = {...data.groups};
              if (value == null) {
                newRoles.remove(item.key);
              } else {
                newRoles[item.key] = value;
              }
              data.groups = newRoles;
              if (mounted) setState(() {});
            },
          ),
          spacer,
          spacer,
        ]);
      }
    }

    /// Manage multiple roles using the roles array
    if (widget.multipleRoles) {
      inviteWidgets.addAll([
        const Divider(),
        ListTile(
          title: Text(locales.get('label--roles')),
          leading: const Icon(Icons.security),
        ),
        spacer,
      ]);
      inviteWidgets.addAll([
        Column(
          children: List.generate(widget.roles.length, (index) {
            final item = widget.roles[index];
            String labelKey = 'label--$item';
            String label = locales.get(labelKey);
            // if the label is not found, use the item as the label
            if (label == labelKey) {
              label = item[0].toUpperCase() + item.substring(1);
            }
            return CheckboxListTile(
              value: data.roles.contains(item),
              onChanged: (value) {
                error = null;
                if (value == true) {
                  data.roles = [...data.roles, item];
                } else {
                  data.roles =
                      data.roles.where((element) => element != item).toList();
                }
                if (mounted) setState(() {});
              },
              title: Text(label),
            );
          }),
        ),
        spacer,
        spacer,
      ]);
    }
    if (error != null) {
      inviteWidgets.addAll([
        ListTile(
          tileColor: theme.colorScheme.errorContainer,
          textColor: theme.colorScheme.onErrorContainer,
          iconColor: theme.colorScheme.onErrorContainer,
          title: Text(locales.get(error)),
          leading: const Icon(Icons.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
              style: TextButton.styleFrom(foregroundColor: Colors.deepOrange),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.person_add),
              label: Text(actionLabel),
              onPressed: canCall ? addUser : null,
            ),
          ],
        ),
      )
    ]);

    return ContentContainer(
      size: widget.size,
      child: SimpleDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.all(20),
        children: inviteWidgets,
      ),
    );
  }
}
