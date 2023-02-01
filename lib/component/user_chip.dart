import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state_user.dart';

/// [UserChip] displays a User's profile name and avatar
class UserChip extends StatefulWidget {
  const UserChip({
    Key? key,
    required this.uid,
    this.minimal = false,
    this.labelStyle,
  }) : super(key: key);
  final String? uid;
  final bool minimal;
  final TextStyle? labelStyle;

  @override
  State<UserChip> createState() => _UserChipState();
}

class _UserChipState extends State<UserChip> {
  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) return const SizedBox(width: 0, height: 0);
    final stateUser = Provider.of<StateUser>(context);
    final user = stateUser.getUser(widget.uid!);
    String label = user.id!;
    if (user.username != null) label = user.username!;
    if (user.name.isNotEmpty) label = user.name;
    if (widget.minimal) return Text(label, style: widget.labelStyle);
    return Chip(
      avatar: UserAvatar(
        avatar: user.avatar,
        firstName: user.firstName,
        lastName: user.lastName,
        name: user.name,
        presence: user.presence,
      ),
      label: Text(label),
    );
  }
}
