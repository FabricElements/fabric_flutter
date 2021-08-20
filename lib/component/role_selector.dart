import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';

class RoleSelector extends StatefulWidget {
  RoleSelector({
    Key? key,
    this.roles,
    required this.onChange,
  }) : super(key: key);
  final List<String>? roles;
  final Function onChange;

  @override
  _RoleSelectorState createState() => _RoleSelectorState();
}

class _RoleSelectorState extends State<RoleSelector> {
  String? roleSelect;

  @override
  void initState() {
    super.initState();
    roleSelect = null;
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations locales = AppLocalizations.of(context)!;
    List<String> _roles = widget.roles ?? ["admin", "user"];
    List<DropdownMenuItem> rolesDrop = [];

    /// Create options and locales from roles
    for (int i = 0; i < _roles.length; i++) {
      String _role = _roles[i];
      rolesDrop.add(DropdownMenuItem(
        value: _role,
        child: Text(locales.get("label--$_role")),
      ));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButton(
        hint: Text(locales.get("label--choose-role")),
        value: roleSelect,
        isExpanded: true,
        items: rolesDrop,
        onChanged: (dynamic value) {
          roleSelect = value;
          widget.onChange(roleSelect);
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }
}
