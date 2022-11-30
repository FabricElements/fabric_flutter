import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state_user.dart';

class UserRoleContent extends StatefulWidget {
  const UserRoleContent({
    Key? key,
    required this.compareData,
    this.roles = const ['admin'],
    this.group,
    required this.child,
    this.placeholder,
    this.path,
  }) : super(key: key);
  final Map<String, dynamic>? compareData;
  final List<String> roles;
  final dynamic group;
  final Widget child;

  /// [path]: Redirects the view to named path when present
  final String? path;
  final Widget? placeholder;

  @override
  State<UserRoleContent> createState() => _UserRoleContentState();
}

class _UserRoleContentState extends State<UserRoleContent> {
  @override
  Widget build(BuildContext context) {
    Widget _placeholder =
        widget.placeholder ?? const Center(child: CircularProgressIndicator());
    if (widget.path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.popAndPushNamed(context, widget.path!);
      });
      return _placeholder;
    }
    final stateUser = Provider.of<StateUser>(context);
    final hasAccess = stateUser.accessByRole(
      group: widget.group,
      roles: widget.roles,
    );
    if (!hasAccess) {
      return _placeholder;
    }
    return widget.child;
  }
}
