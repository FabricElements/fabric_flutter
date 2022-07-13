import 'package:flutter/material.dart';

import '../helper/app_localizations_delegate.dart';

class RoleSelector extends StatefulWidget {
  const RoleSelector({
    Key? key,
    this.roles,
    required this.onChange,
    this.asList = false,
  }) : super(key: key);
  final List<String>? roles;
  final Function onChange;
  final bool asList;

  @override
  State<RoleSelector> createState() => _RoleSelectorState();
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
    List<String> _roles = widget.roles ?? ['user', 'admin'];
    // if (roleSelect == null) roleSelect = _roles.first;
    List<DropdownMenuItem> rolesDrop = [];
    List<Widget> rolesList = [];

    /// Create options and locales from roles
    for (int i = 0; i < _roles.length; i++) {
      String _role = _roles[i];
      rolesDrop.add(DropdownMenuItem(
        value: _role,
        child: Text(locales.get('label--$_role')),
      ));
      rolesList.add(RadioListTile(
        contentPadding: const EdgeInsets.only(left: 8),
        title: Text(locales.get('label--$_role')),
        value: _role,
        groupValue: roleSelect,
        onChanged: (String? value) {
          roleSelect = value;
          widget.onChange(roleSelect);
          if (mounted) setState(() {});
        },
      ));
    }

    Widget dropdownWidget = DropdownButton(
      hint: Text(locales.get('label--choose-role')),
      value: roleSelect,
      isExpanded: true,
      items: rolesDrop,
      onChanged: (dynamic value) {
        roleSelect = value;
        widget.onChange(roleSelect);
        if (mounted) setState(() {});
      },
    );

    Widget listWidget = Column(children: rolesList);

    Widget options = widget.asList ? listWidget : dropdownWidget;

    return options;
  }
}
