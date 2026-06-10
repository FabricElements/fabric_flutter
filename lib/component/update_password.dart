import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../helper/regex_helper.dart';
import '../serialized/password_data.dart';
import './input_data.dart';
import 'alert_data.dart';

/// Guides the user through validating and confirming a password change.
///
/// The widget progressively reveals each field only after the prior step is
/// valid, which helps prevent accidental submissions and keeps surrounding
/// settings views lightweight.
class UpdatePassword extends StatefulWidget {
  /// Creates a password update form that reports a confirmed [PasswordData].
  ///
  /// The [callback] runs only after the user accepts the warning dialog, so
  /// consumers receive values that have already passed the widget's local
  /// validation flow.
  const UpdatePassword({super.key, required this.callback});

  /// Receives the confirmed [PasswordData] after the user approves the change.
  ///
  /// The callback is deferred until the warning dialog action is selected,
  /// which keeps parent widgets from reacting to incomplete edits.
  final Function(PasswordData) callback;

  /// Creates mutable form state for the password update flow.
  ///
  /// The returned [_UpdatePasswordState] stores staged field values so the UI
  /// can reveal each step as validation succeeds.
  @override
  State<UpdatePassword> createState() => _UpdatePasswordState();
}

/// Tracks staged password values and validation results for [UpdatePassword].
///
/// The state keeps transient entries separate from the parent widget until the
/// user confirms the warning dialog and [UpdatePassword.callback] is invoked.
class _UpdatePasswordState extends State<UpdatePassword> {
  /// Stores the user's current password entry.
  ///
  /// The value remains empty until the first field changes, allowing the form
  /// to hide later steps during the initial render.
  late String current;

  /// Stores the proposed new password before confirmation.
  ///
  /// The value is reset when the current entry changes so the repeated field is
  /// revalidated against the latest candidate password.
  late String password1;

  /// Stores the repeated new password used for confirmation.
  ///
  /// The value helps surface mismatch messaging before the submission action is
  /// displayed.
  late String password2;

  /// Indicates whether the collected values are ready to submit.
  ///
  /// The flag is recalculated during [build] so the button appears only when
  /// the current password, regex validation, and confirmation all succeed.
  late bool ok;

  /// Resets the staged password fields to their initial empty values.
  ///
  /// The method is used during initialization and after a successful callback
  /// so subsequent edits restart from a clean state.
  void reset() {
    current = '';
    password1 = '';
    password2 = '';
    ok = false;
  }

  /// Initializes the form with empty password values.
  ///
  /// Calling [reset] keeps the initial field state aligned with the state used
  /// after a completed password update.
  @override
  void initState() {
    super.initState();
    reset();
  }

  /// Builds a staged password form for the provided [BuildContext].
  ///
  /// The form uses [RegexHelper.password] and localized error strings to reveal
  /// follow-up fields only when earlier entries are valid, and it opens a
  /// confirmation dialog before invoking [UpdatePassword.callback].
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);

    String? errorValidation;
    String? errorValidation2;
    bool newPasswordOk = RegexHelper.password.hasMatch(password1);
    ok = current.isNotEmpty &&
        password1.length > 5 &&
        password2.length > 5 &&
        current != password1 &&
        (password1 == password2) &&
        newPasswordOk;
    if (!ok) {
      if (current == password1) {
        errorValidation = locales.get('alert--password-must-be-different');
      }
      if (password1.isNotEmpty && !newPasswordOk) {
        errorValidation = locales.get('alert--invalid-password');
      } else if (password1.isNotEmpty && password2.isNotEmpty) {
        if (password1 != password2) {
          errorValidation2 = locales.get('alert--password-do-not-match');
        }
      }
    }

    List<Widget> sections = [];
    sections.add(
      InputData(
        autofillHints: const [],
        label: locales.get('label--current-password'),
        hintText: locales.get('label--password'),
        type: InputDataType.secret,
        obscureText: true,
        value: current,
        onChanged: (value) {
          current = value ?? '';
          if (mounted) setState(() {});
        },
      ),
    );
    if (current.isNotEmpty) {
      sections.add(
        InputData(
          label: locales.get('label--new-password'),
          hintText: locales.get('label--password'),
          type: InputDataType.secret,
          obscureText: true,
          value: password1,
          error: errorValidation,
          onChanged: (value) {
            password1 = value ?? '';
            password2 = '';
            if (mounted) setState(() {});
          },
          autofillHints: const [AutofillHints.newPassword],
        ),
      );
    }
    if (password1.isNotEmpty && errorValidation == null) {
      sections.add(
        InputData(
          label: locales.get('label--repeat-new-password'),
          hintText: locales.get('label--password'),
          type: InputDataType.secret,
          obscureText: true,
          value: password2,
          error: errorValidation2,
          onChanged: (value) {
            password2 = value ?? '';
            if (mounted) setState(() {});
          },
          autofillHints: const [AutofillHints.newPassword],
        ),
      );
    }

    if (ok) {
      sections.add(
        FilledButton(
          onPressed: () {
            alertData(
              context: context,
              title: locales.get('label--confirm-are-you-sure-update-label', {
                'label': locales.get('label--password'),
              }),
              body: locales.get('alert--action-permanent'),
              action: ButtonOptions(
                onTap: () {
                  widget.callback(
                    PasswordData(
                      currentPassword: current,
                      newPassword: password1,
                    ),
                  );
                  reset();
                  if (mounted) setState(() {});
                },
                label: 'label--update',
              ),
              type: AlertType.warning,
              widget: AlertWidget.dialog,
            );
          },
          child: Text(locales.get('label--update')),
        ),
      );
    }

    sections = sections
        .map(
          (e) => Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.only(bottom: 16),
            child: e,
          ),
        )
        .toList();
    return Flex(
      direction: Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}
