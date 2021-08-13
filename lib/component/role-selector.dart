import 'package:flutter/material.dart';

class RoleSelector extends StatefulWidget {
  RoleSelector({
    Key? key,
    required this.hintText,
    required this.list,
    required this.onChange,
  }) : super(key: key);
  final Map<String, dynamic> list;
  final String? hintText;
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
    List<DropdownMenuItem> rolesDrop = [];

    if (widget.list.isNotEmpty) {
      widget.list.forEach(
        (key, value) => rolesDrop.add(
          DropdownMenuItem(
            value: key,
            child: Text(value),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButton(
        hint: Text(
          widget.hintText!,
          // style: TextStyle(
          //   color: Colors.white,
          // ),
        ),
        value: roleSelect,
        isExpanded: true,
        // style: TextStyle(
        //   color: Colors.white,
        // ),
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
