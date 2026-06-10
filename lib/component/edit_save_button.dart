import 'package:fabric_flutter/component/alert_data.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';

/// Toggles between an edit action and save or cancel actions for inline editors.
///
/// This widget centralizes the small state machine many settings panels need: idle,
/// editing, and optionally confirming destructive transitions. Keeping the logic here
/// makes parent widgets simpler and ensures consistent affordances across forms.
class EditSaveButton extends StatefulWidget {
  /// Creates a compact action group for entering, saving, or cancelling edit mode.
  const EditSaveButton({
    super.key,
    this.active = false,
    required this.cancel,
    required this.save,
    required this.edit,
    this.confirm = false,
    this.alertWidget = AlertWidget.snackBar,
    this.alertType = AlertType.basic,
    this.labels = false,
    this.direction = Axis.horizontal,
  });

  /// Indicates whether the save and cancel actions should be shown instead of edit.
  final bool active;

  /// Runs when the user dismisses the current edit session.
  final VoidCallback cancel;

  /// Runs when the user confirms the current edits.
  final VoidCallback save;

  /// Runs when the user first enters edit mode.
  final VoidCallback edit;

  /// Determines whether save and cancel actions require an extra confirmation prompt.
  final bool confirm;

  /// Chooses how confirmation prompts are presented when [confirm] is enabled.
  final AlertWidget alertWidget;

  /// Controls the visual tone of confirmation prompts shown by [alertWidget].
  final AlertType alertType;

  /// Replaces icon-only controls with labeled buttons for more explicit layouts.
  final bool labels;

  /// Arranges the rendered action buttons horizontally or vertically.
  final Axis direction;

  /// Creates the state that resolves confirmation prompts before invoking callbacks.
  @override
  State<EditSaveButton> createState() => _EditSaveButtonState();
}

/// Builds the appropriate action set for the current edit lifecycle stage.
class _EditSaveButtonState extends State<EditSaveButton> {
  /// Builds either the edit trigger or the active save and cancel controls.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locales = AppLocalizations.of(context);

    void update() async {
      if (!widget.confirm) {
        widget.save();
        return;
      }
      alertData(
        context: context,
        title: locales.get('label--confirm-are-you-sure-update'),
        action: ButtonOptions(onTap: widget.save, label: 'label--update'),
        type: widget.alertType,
        widget: widget.alertWidget,
      );
    }

    void cancel() async {
      if (!widget.confirm) {
        widget.cancel();
        return;
      }
      alertData(
        context: context,
        type: widget.alertType,
        widget: widget.alertWidget,
        title: locales.get('label--confirm-are-you-sure-cancel'),
        action: ButtonOptions(onTap: widget.cancel, label: 'label--cancel'),
      );
    }

    Widget cancelButton = IconButton(
      onPressed: cancel,
      icon: const Icon(Icons.cancel, color: Colors.deepOrange),
    );

    Widget updateButton = IconButton(
      onPressed: update,
      icon: Icon(Icons.save, color: theme.colorScheme.primary),
    );

    Widget editButton = IconButton(
      icon: Icon(Icons.edit, color: theme.colorScheme.primary),
      onPressed: widget.edit,
    );

    if (widget.labels) {
      cancelButton = OutlinedButton.icon(
        onPressed: cancel,
        icon: const Icon(Icons.cancel),
        label: Text(locales.get('label--cancel')),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              theme.buttonTheme.colorScheme?.secondary ?? Colors.deepOrange,
          iconColor:
              theme.buttonTheme.colorScheme?.secondary ?? Colors.deepOrange,
        ),
      );

      updateButton = FilledButton.icon(
        onPressed: update,
        icon: const Icon(Icons.save),
        label: Text(locales.get('label--update')),
      );

      editButton = FilledButton.icon(
        icon: const Icon(Icons.edit),
        onPressed: widget.edit,
        label: Text(locales.get('label--edit')),
      );
    }

    List<Widget> buttons = [];

    if (widget.active) {
      buttons = [cancelButton, const SizedBox(width: 8), updateButton];
    } else {
      buttons = [editButton];
    }

    return Flex(
      direction: widget.direction,
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }
}
