import 'package:flutter/material.dart';

import '../helper/alert_helper.dart';
import '../helper/app_localizations_delegate.dart';

/// [EditSaveButton] displays a simple way to show/hide edit buttons
class EditSaveButton extends StatefulWidget {
  const EditSaveButton({
    Key? key,
    required this.active,
    required this.cancelCallback,
    required this.confirmCallback,
    required this.editCallback,
  }) : super(key: key);

  /// if [active] the controls to edit are available
  final bool active;

  /// [cancelCallback] is called when the cancel button is clicked
  final VoidCallback cancelCallback;

  /// [confirmCallback] is called when the confirm button is clicked
  final VoidCallback confirmCallback;

  /// [confirmCallback] is called when the edit button is clicked
  final VoidCallback editCallback;

  @override
  State<EditSaveButton> createState() => _EditSaveButtonState();
}

class _EditSaveButtonState extends State<EditSaveButton> {
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    AlertHelper alert = AlertHelper(
      context: context,
      mounted: mounted,
    );
    AppLocalizations locales = AppLocalizations.of(context)!;
    if (widget.active) {
      return Wrap(
        children: [
          IconButton(
            onPressed: () {
              alert.show(
                title: locales.get("label--confirm-are-you-sure-cancel"),
                actionCallback: widget.cancelCallback,
                type: AlertType.warning,
              );
            },
            icon: Icon(Icons.cancel, color: Colors.deepOrange),
          ),
          IconButton(
            onPressed: () {
              alert.show(
                title: locales.get("label--confirm-are-you-sure-update"),
                actionCallback: widget.confirmCallback,
                type: AlertType.basic,
              );
            },
            icon: Icon(Icons.save, color: theme.colorScheme.primary),
          )
        ],
      );
    }
    return IconButton(
      icon: Icon(Icons.edit, color: theme.colorScheme.primary),
      onPressed: widget.editCallback,
    );
  }
}
