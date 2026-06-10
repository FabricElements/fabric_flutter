import 'package:fabric_flutter/component/alert_data.dart';
import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';

/// Toggles between an edit action and save or cancel actions for inline editors.
///
/// This widget centralizes the edit lifecycle for small forms by showing either an
/// edit trigger or the active save and cancel controls. It also coordinates
/// optional confirmation prompts so parent widgets can delegate that branching
/// behavior to a single reusable component.
class EditSaveButton extends StatefulWidget {
  /// Creates a compact action group for entering, saving, or cancelling edit mode.
  ///
  /// The callbacks supplied by [cancel], [save], and [edit] define the parent
  /// widget's edit workflow, while the remaining arguments tune how the actions
  /// are presented and whether confirmations are required before destructive
  /// transitions.
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
  ///
  /// When `true`, the widget renders the active editing controls so the user can
  /// either persist or discard changes. When `false`, the widget shows only the
  /// edit entry point.
  final bool active;

  /// Stores the callback that dismisses the current edit session.
  ///
  /// This callback runs immediately when [confirm] is `false`, or after the user
  /// accepts the cancellation prompt when confirmation is enabled.
  final VoidCallback cancel;

  /// Stores the callback that confirms the current edits.
  ///
  /// This callback runs directly when [confirm] is `false`, or from the
  /// confirmation action created by the alert flow when confirmation is enabled.
  final VoidCallback save;

  /// Stores the callback that enters edit mode.
  ///
  /// The widget invokes this callback from the edit action without any additional
  /// confirmation because entering edit mode is always a non-destructive step.
  final VoidCallback edit;

  /// Determines whether save and cancel actions require an extra confirmation prompt.
  ///
  /// When `true`, both active actions route through [alertWidget] before calling
  /// their respective callbacks. When `false`, the callbacks execute immediately.
  final bool confirm;

  /// Chooses how confirmation prompts are presented when [confirm] is enabled.
  ///
  /// The selected [AlertWidget] controls whether the prompt appears as a snack
  /// bar, dialog, or another supported alert surface.
  final AlertWidget alertWidget;

  /// Controls the visual tone of confirmation prompts shown by [alertWidget].
  ///
  /// The selected [AlertType] lets the prompt match the severity or style of the
  /// surrounding form interaction.
  final AlertType alertType;

  /// Determines whether the actions render labels alongside their icons.
  ///
  /// When `true`, the widget uses button variants with localized text to make the
  /// controls more explicit. When `false`, it keeps the layout compact with icons
  /// only.
  final bool labels;

  /// Determines how the rendered action buttons are laid out.
  ///
  /// The [Axis] value is passed directly to [Flex] so parents can choose a
  /// horizontal toolbar or a vertical action stack without changing the logic.
  final Axis direction;

  /// Creates the state that resolves confirmation prompts before invoking callbacks.
  ///
  /// The returned [_EditSaveButtonState] keeps the widget stateful so the button
  /// set can rebuild correctly as the parent toggles [active] or presentation
  /// settings.
  @override
  State<EditSaveButton> createState() => _EditSaveButtonState();
}

/// Builds the appropriate action set for the current edit lifecycle stage.
///
/// This state object derives localized labels, theme colors, and confirmation
/// behavior from the surrounding [BuildContext]. It keeps the rendering logic for
/// the inactive and active button sets in one place.
class _EditSaveButtonState extends State<EditSaveButton> {
  /// Builds either the edit trigger or the active save and cancel controls.
  ///
  /// The returned widget adapts its button styles according to [EditSaveButton.labels]
  /// and switches between inactive and active layouts based on
  /// [EditSaveButton.active]. When [EditSaveButton.confirm] is `true`, the save
  /// and cancel actions open confirmation prompts before invoking their callbacks.
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
