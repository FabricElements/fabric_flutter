import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../helper/regex_helper.dart';
import '../serialized/password_data.dart';
import './input_data.dart';
import 'alert_data.dart';

/// Guides the user through validating and confirming a password change.
///
/// The widget progressively reveals fields as the current password and the new
/// password become valid, which helps reduce accidental submissions and keeps
/// the surrounding settings screen lightweight.
class UpdatePassword extends StatefulWidget {
  /// Creates a password update form that reports a validated [PasswordData]
  /// object through [callback].
  const UpdatePassword({super.key, required this.callback});

  /// Receives the confirmed password payload after the user accepts the warning
  /// dialog.
  final Function(PasswordData) callback;

  /// Creates mutable form state for the password update flow.
  @override
  State<UpdatePassword> createState() => _UpdatePasswordState();
}

/// Tracks the staged password values and validation results for
/// [UpdatePassword].
class _UpdatePasswordState extends State<UpdatePassword> {
  /// Holds the user's current password entry.
  late String current;
  /// Holds the proposed new password before confirmation.
  late String password1;
  /// Holds the repeated new password used to confirm the change.
  late String password2;
  /// Indicates whether the collected values are ready to submit.
  late bool ok;

  /// Resets the form after a successful submission or the initial mount.
  void reset() {
    current = '';
    password1 = '';
    password2 = '';
    ok = false;
  }

  /// Initializes the form with empty password values.
  @override
  void initState() {
    super.initState();
    reset();
  }

  /// Builds a staged password form that only exposes the next step when the
  /// current step is valid.
  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.of(context);

    String? errorValidation;
    String? errorValidation2;
    bool newPasswordOk = RegexHelper.password.hasMatch(password1);
    ok =
        current.isNotEmpty &&
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

    /// Add BoxConstraints
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
