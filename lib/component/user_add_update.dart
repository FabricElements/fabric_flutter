import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/input_validation.dart';
import '../helper/options.dart';
import '../helper/regex_helper.dart';
import '../helper/utils.dart';
import '../serialized/user_data.dart';
import 'alert_data.dart';
import 'content_container.dart';
import 'input_data.dart';

/// Presents a full-screen form for creating or updating a [UserData] record.
///
/// The widget adapts its fields to the flags passed by the caller so the same form
/// can support invite flows, profile edits, and role management without duplicating
/// UI. It keeps a cloned copy of [user] in state so partially entered data survives
/// rebuilds and can be safely cancelled before [onConfirm] persists anything.
class UserAddUpdate extends StatefulWidget {
  /// Creates a configurable user form with optional identity, password, and role fields.
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
    this.passwordRegex,
    this.passwordError,
    this.disabled = false,
  });

  /// Lists the role values available when role selection is enabled.
  final List<String> roles;

  /// Persists the edited [UserData] and optionally scopes it to [group].
  final Function(UserData data, {String? group}) onConfirm;

  /// Enables the email input when this workflow needs email-based identity.
  final bool email;

  /// Enables the phone input when this workflow needs SMS-ready contact data.
  final bool phone;

  /// Enables the username input for systems that support handle-based sign-in.
  final bool username;

  /// Enables first and last name fields for flows that require display names.
  final bool name;

  /// Shows a single-role dropdown when users should have exactly one role.
  final bool role;

  /// Shows a multi-select role checklist when users may hold several roles.
  final bool multipleRoles;

  /// Enables password entry for flows that provision or reset credentials directly.
  final bool password;

  /// Runs after a successful save so parent widgets can refresh surrounding data.
  final Function onChanged;

  /// Provides the existing user to edit, or `null` to start from a blank record.
  final UserData? user;

  /// Identifies the group that receives the saved user assignment, when applicable.
  final String? group;

  /// Supplies the localization key shown after a successful confirmation.
  final String successMessage;

  /// Maps group identifiers to the role options available for each group-specific picker.
  ///
  /// The selected values are written back into [UserData.groups], which lets the form
  /// model per-group privileges without requiring a separate editor for every group.
  final Map<String, List<String>>? groups;

  /// Constrains the maximum width of the surrounding [ContentContainer].
  final ContentContainerSize size;

  /// Overrides the default password rule when a workflow needs stricter validation.
  final RegExp? passwordRegex;

  /// Overrides the localized message shown when password validation fails.
  final String? passwordError;

  /// Makes the form read-only so callers can reuse it as a detail view.
  final bool disabled;

  /// Creates the mutable form state that owns the editable [UserData] clone.
  @override
  State<UserAddUpdate> createState() => _UserAddUpdateState();
}

/// Coordinates validation, submission, and transient error handling for [UserAddUpdate].
class _UserAddUpdateState extends State<UserAddUpdate> {
  /// Tracks whether a save request is currently in flight so controls can be disabled.
  late bool sending;
  /// Stores an optional internal change hook for future extensions of the form state.
  Function? onChange;
  /// Holds the editable copy of the user record displayed by the form.
  late UserData data;
  /// Captures the latest submission error to surface it inline to the user.
  String? error;

  /// Resets the local user draft to match the current widget configuration.
  ///
  /// Cloning the incoming [UserData] prevents accidental mutation of parent state, and
  /// the role fallback keeps the form from holding a stale role that is no longer in the
  /// allowed option set after a rebuild.
  void reset() {
    /// Set default user data
    final base = widget.user ?? UserData(id: widget.user?.id);

    /// Reset the user data to prevent changes to the original object and missing data
    data = UserData.fromJson(base.toJson());

    /// If the role assigned doesn't match the options, set the first role from the list
    if (widget.roles.isNotEmpty && !widget.roles.contains(data.role)) {
      data.role = widget.roles.first;
    }
    sending = false;
    error = null;
  }

  /// Seeds the form state the first time the widget is inserted into the tree.
  @override
  void initState() {
    super.initState();
    reset();
  }

  /// Builds the adaptive user form, including validation, role editors, and actions.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context);
    ScrollController controller = ScrollController();
    final passwordRegex = widget.passwordRegex ?? RegexHelper.password;
    bool canCall = sending == false;
    bool validPhone = data.phone != null && data.phone!.isNotEmpty;
    bool validEmail = data.email != null && data.email!.isNotEmpty;
    bool validUsername = data.username != null && data.username!.isNotEmpty;
    canCall = canCall && (validPhone || validEmail || validUsername);
    if (widget.name) {
      canCall =
          canCall &&
          data.firstName != null &&
          data.firstName!.length > 1 &&
          data.lastName != null &&
          data.lastName!.length > 1;
    }
    if (widget.password) {
      canCall = canCall && data.password != null && data.password!.isNotEmpty;
      bool newPasswordOk = passwordRegex.hasMatch(data.password ?? '');
      canCall = canCall && newPasswordOk;
    }
    const spacer = SizedBox(height: 16, width: 16);
    String title = locales.get(
      data.id == null ? 'label--add-label' : 'label--update',
      {'label': locales.get('label--user')},
    );
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
        if (widget.role) {
          assert(data.role.isNotEmpty, 'You must select a user role');
        }
        assert(
          data.username != null || data.email != null || data.phone != null,
          'username, email or phone must not be null',
        );
        await widget.onConfirm(data, group: widget.group);
        alertData(
          context: context,
          body: locales.get(widget.successMessage),
          type: AlertType.success,
          duration: 3,
        );
        // Check if the widget is still 'alive' before using the context
        if (context.mounted) {
          Navigator.of(context).pop();
        }
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
        disabled: widget.disabled,
        autofillHints: const [],
        prefixIcon: const Icon(Icons.phone),
        label: locales.get('label--phone-number'),
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
        disabled: widget.disabled,
        autofillHints: const [],
        prefixIcon: const Icon(Icons.email),
        label: locales.get('label--email'),
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
        disabled: widget.disabled,
        autofillHints: const [],
        prefixIcon: const Icon(Icons.alternate_email),
        label: locales.get('label--username'),
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
      disabled: widget.disabled,
      autofillHints: const [],
      label: locales.get('label--first-name'),
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
      disabled: widget.disabled,
      autofillHints: const [],
      label: locales.get('label--last-name'),
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

    /// Password input
    Widget passwordInput = InputData(
      disabled: widget.disabled,
      autofillHints: const [],
      prefixIcon: const Icon(Icons.lock),
      label: locales.get('label--password'),
      value: data.password,
      type: InputDataType.secret,
      validator: (value) => inputValidation.validateMatch(
        regex: passwordRegex,
        value: value,
        message: widget.passwordError ?? locales.get('alert--invalid-password'),
      ),
      onChanged: (value) {
        error = null;
        data.password = value;
        if (mounted) setState(() {});
      },
      maxLength: 20,
    );

    List<Widget> inviteWidgets = [spacer];
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
      inviteWidgets.addAll([emailInput, spacer]);
    }
    if (widget.phone) {
      inviteWidgets.addAll([phoneInput, spacer]);
    }
    if (widget.username) {
      inviteWidgets.addAll([usernameInput, spacer]);
    }
    if (widget.password) {
      inviteWidgets.addAll([passwordInput, spacer]);
    }
    if (widget.role) {
      inviteWidgets.addAll([
        InputData(
          disabled: widget.disabled,
          autofillHints: const [],
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
            disabled: widget.disabled,
            autofillHints: const [],
            label: locales.get('label--role-for-label', {
              'label': locales.get('label--${item.key}'),
            }),
            value: data.groups[item.key],
            type: InputDataType.dropdown,
            options: List.generate(groupsRoles.length, (index) {
              final item = groupsRoles[index];
              String labelKey = 'label--$item';
              String label = locales.get(labelKey);
              if (item.contains('_') || item.contains(':')) {
                label = item;
              } else if (label.contains('--')) {
                // if the label is not found, use the item as the label
                label = item[0].toUpperCase() + item.substring(1);
              }
              return ButtonOptions(value: item, label: label);
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
            if (item.contains('_') || item.contains(':')) {
              label = item;
            } else if (label.contains('--')) {
              // if the label is not found, use the item as the label
              label = item[0].toUpperCase() + item.substring(1);
            }
            return CheckboxListTile(
              value: data.roles.contains(item),
              onChanged: (value) {
                error = null;
                if (value == true) {
                  data.roles = [...data.roles, item];
                } else {
                  data.roles = data.roles
                      .where((element) => element != item)
                      .toList();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              label: Text(
                locales.get(widget.disabled ? 'label--done' : 'label--cancel'),
              ),
              onPressed: () {
                Navigator.pop(context, 'cancel');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                iconColor: Colors.deepOrange,
              ),
            ),
            const Spacer(),
            if (!widget.disabled)
              FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: Text(actionLabel),
                onPressed: canCall ? addUser : null,
              ),
          ],
        ),
      ),
    ]);

    return ContentContainer(
      size: widget.size,
      child: Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Scrollbar(
            thumbVisibility: true,
            interactive: true,
            trackVisibility: true,
            controller: controller,
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.only(
                bottom: 64,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(children: inviteWidgets),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
