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
/// The widget adapts its fields to the flags passed by the caller so the same
/// form can support invite flows, profile edits, and role management without
/// duplicating UI. It keeps a cloned copy of [user] in state so partially
/// entered data survives rebuilds and can be safely cancelled before
/// [onConfirm] persists anything.
class UserAddUpdate extends StatefulWidget {
  /// Creates a configurable user form with optional identity, password, and
  /// role fields.
  ///
  /// Callers enable only the sections they need, which lets the same widget
  /// serve account creation, profile editing, and administrative role
  /// management flows.
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
  ///
  /// The form uses these values for both single-role and multi-role pickers so
  /// every role-editing control stays aligned with the same allowed options.
  final List<String> roles;

  /// Persists the edited [UserData] and optionally scopes it to [group].
  ///
  /// The callback receives the mutable draft after validation passes and is
  /// responsible for saving it to the backing data source.
  final Function(UserData data, {String? group}) onConfirm;

  /// Enables the email input when this workflow needs email-based identity.
  ///
  /// Leaving this `false` hides the email field so the form can support flows
  /// that rely on other identifiers.
  final bool email;

  /// Enables the phone input when this workflow needs SMS-ready contact data.
  ///
  /// Leaving this `false` hides the phone field and keeps phone validation out
  /// of the submission rules.
  final bool phone;

  /// Enables the username input for systems that support handle-based sign-in.
  ///
  /// Leaving this `false` removes username editing so callers can restrict the
  /// form to email-only or phone-only identity flows.
  final bool username;

  /// Enables first and last name fields for flows that require display names.
  ///
  /// When this flag is `true`, submission also requires both name parts to have
  /// more than one character.
  final bool name;

  /// Shows a single-role dropdown when users should have exactly one role.
  ///
  /// The selected value is written to [UserData.role] and defaults to the first
  /// entry in [roles] when the current value is invalid.
  final bool role;

  /// Shows a multi-select role checklist when users may hold several roles.
  ///
  /// The selected values are written to [UserData.roles], which lets callers
  /// model broader permission sets than [role] alone can represent.
  final bool multipleRoles;

  /// Enables password entry for flows that provision or reset credentials.
  ///
  /// When this flag is `true`, submission requires a non-empty password that
  /// matches [passwordRegex] or the default rule from [RegexHelper.password].
  final bool password;

  /// Runs after a successful save so parent widgets can refresh surrounding data.
  ///
  /// The callback is awaited after the dialog closes, which gives parent views a
  /// place to reload lists or update local state.
  final Function onChanged;

  /// Provides the existing user to edit, or `null` to start from a blank record.
  ///
  /// The incoming value is cloned into local state so in-progress edits do not
  /// mutate the caller's instance before confirmation.
  final UserData? user;

  /// Identifies the group that receives the saved user assignment, when applicable.
  ///
  /// The value is forwarded unchanged to [onConfirm] so external persistence code
  /// can apply group-specific behavior.
  final String? group;

  /// Supplies the localization key shown after a successful confirmation.
  ///
  /// The key is resolved through [AppLocalizations] before the success alert is
  /// displayed.
  final String successMessage;

  /// Maps group identifiers to the role options available for each group-specific picker.
  ///
  /// The selected values are written back into [UserData.groups], which lets the
  /// form model per-group privileges without requiring a separate editor for
  /// every group.
  final Map<String, List<String>>? groups;

  /// Constrains the maximum width of the surrounding [ContentContainer].
  ///
  /// This keeps the full-screen dialog readable on larger displays while still
  /// allowing the caller to choose a wider or narrower presentation.
  final ContentContainerSize size;

  /// Overrides the default password rule when a workflow needs stricter validation.
  ///
  /// Passing `null` falls back to [RegexHelper.password] so common password flows
  /// can reuse the package default.
  final RegExp? passwordRegex;

  /// Overrides the localized message shown when password validation fails.
  ///
  /// Passing `null` uses the standard invalid-password translation key supplied
  /// by the current [AppLocalizations] instance.
  final String? passwordError;

  /// Makes the form read-only so callers can reuse it as a detail view.
  ///
  /// When this flag is `true`, every input is disabled and the submit action is
  /// hidden.
  final bool disabled;

  /// Creates the mutable form state that owns the editable [UserData] clone.
  ///
  /// The returned [_UserAddUpdateState] manages validation, submission, and
  /// inline error rendering for the dialog.
  @override
  State<UserAddUpdate> createState() => _UserAddUpdateState();
}

/// Coordinates validation, submission, and transient error handling for [UserAddUpdate].
///
/// The state object keeps the editable draft separate from the parent widget so
/// the dialog can be dismissed without leaking partial edits back to the caller.
class _UserAddUpdateState extends State<UserAddUpdate> {
  /// Tracks whether a save request is currently in flight so controls can be disabled.
  ///
  /// The flag prevents duplicate submissions and helps the form compute whether
  /// the primary action should remain enabled.
  late bool sending;

  /// Stores an optional internal change hook for future extensions of the form state.
  ///
  /// The field is currently unused, but it preserves room for internal change
  /// notifications without altering the widget contract.
  Function? onChange;

  /// Holds the editable copy of the user record displayed by the form.
  ///
  /// The draft is recreated from [widget.user] so the UI can mutate values
  /// freely before [widget.onConfirm] commits them.
  late UserData data;

  /// Captures the latest submission error to surface it inline to the user.
  ///
  /// A `null` value hides the error tile, while any stored key or message is
  /// localized and rendered near the action buttons.
  String? error;

  /// Resets the local user draft to match the current widget configuration.
  ///
  /// Cloning the incoming [UserData] prevents accidental mutation of parent
  /// state, and the role fallback keeps the form from holding a stale role that
  /// is no longer in the allowed option set after a rebuild.
  void reset() {
    final base = widget.user ?? UserData(id: widget.user?.id);

    data = UserData.fromJson(base.toJson());

    if (widget.roles.isNotEmpty && !widget.roles.contains(data.role)) {
      data.role = widget.roles.first;
    }
    sending = false;
    error = null;
  }

  /// Seeds the form state the first time the widget is inserted into the tree.
  ///
  /// Initializing through [reset] ensures the editable draft and status flags use
  /// the same logic as later rebuild-driven resets.
  @override
  void initState() {
    super.initState();
    reset();
  }

  /// Builds the adaptive user form, including validation, role editors, and actions.
  ///
  /// The layout only renders the sections enabled by [widget], which keeps the
  /// dialog reusable across several account-management workflows.
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

    /// Persists the edited user and closes the dialog after a successful save.
    ///
    /// The handler forwards [data] to [widget.onConfirm], shows a localized
    /// success alert, and records any thrown error so the UI can render it
    /// inline without losing the current draft.
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
