import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/app_localizations_delegate.dart';
import '../helper/options.dart';
import '../state/state_alert.dart';

/// [EditSaveButton] displays a simple way to show/hide edit buttons
class EditSaveButton extends StatefulWidget {
  const EditSaveButton({
    Key? key,
    this.active = false,
    required this.cancel,
    required this.save,
    required this.edit,
    this.confirm = false,
  }) : super(key: key);

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

  @override
  State<EditSaveButton> createState() => _EditSaveButtonState();
}

class _EditSaveButtonState extends State<EditSaveButton> {
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    final alert = Provider.of<StateAlert>(context, listen: false);
    AppLocalizations locales = AppLocalizations.of(context)!;
    if (widget.active) {
      return Wrap(
        children: [
          IconButton(
            onPressed: () async {
              if (!widget.confirm) {
                widget.cancel();
                return;
              }
              alert.show(AlertData(
                title: locales.get('label--confirm-are-you-sure-cancel'),
                action: ButtonOptions(
                  onTap: widget.cancel,
                  label: 'label--cancel',
                ),
                type: AlertType.warning,
              ));
            },
            icon: const Icon(Icons.cancel, color: Colors.deepOrange),
          ),
          IconButton(
            onPressed: () async {
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
                type: AlertType.basic,
              ));
            },
            icon: Icon(Icons.save, color: theme.colorScheme.primary),
          )
        ],
      );
    }
    return IconButton(
      icon: Icon(Icons.edit, color: theme.colorScheme.primary),
      onPressed: widget.edit,
    );
  }
}
