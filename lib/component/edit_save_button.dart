import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../state/state_alert.dart';

/// EditSaveButton displays a simple way to show/hide edit buttons
class EditSaveButton extends StatefulWidget {
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

  /// if [active] the controls to edit are available
  final bool active;

  /// [cancel] is called when the cancel button is clicked
  final VoidCallback cancel;

  /// [save] is called when the confirm button is clicked
  final VoidCallback save;

  /// [save] is called when the edit button is clicked
  final VoidCallback edit;

  /// Confirm
  final bool confirm;

  final AlertWidget alertWidget;

  final AlertType alertType;

  final bool labels;

  final Axis direction;

  @override
  State<EditSaveButton> createState() => _EditSaveButtonState();
}

class _EditSaveButtonState extends State<EditSaveButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alert = Provider.of<StateAlert>(context, listen: false);
    final locales = AppLocalizations.of(context);

    void update() async {
      if (!widget.confirm) {
        widget.save();
        return;
      }
      alert.show(AlertData(
        title: locales.get('label--confirm-are-you-sure-update'),
        action: ButtonOptions(
          onTap: widget.save,
          label: 'label--update',
        ),
        type: widget.alertType,
        widget: widget.alertWidget,
        clear: true,
      ));
    }

    void cancel() async {
      if (!widget.confirm) {
        widget.cancel();
        return;
      }
      alert.show(AlertData(
        type: widget.alertType,
        widget: widget.alertWidget,
        title: locales.get('label--confirm-are-you-sure-cancel'),
        action: ButtonOptions(
          onTap: widget.cancel,
          label: 'label--cancel',
        ),
        clear: true,
      ));
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
        ),
      );

      updateButton = ElevatedButton.icon(
        onPressed: update,
        icon: const Icon(Icons.save),
        label: Text(locales.get('label--update')),
      );

      editButton = ElevatedButton.icon(
        icon: const Icon(Icons.edit),
        onPressed: widget.edit,
        label: Text(locales.get('label--edit')),
      );
    }

    List<Widget> buttons = [];

    if (widget.active) {
      buttons = [
        cancelButton,
        const SizedBox(width: 8),
        updateButton,
      ];
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
