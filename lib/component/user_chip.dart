import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state_users.dart';
import 'user_avatar.dart';

/// UserChip displays a User's profile name and avatar
class UserChip extends StatefulWidget {
  const UserChip({
    super.key,
    required this.uid,
    this.minimal = false,
    this.labelStyle,
    this.onDeleted,
    this.avatarPrefix,
  });

  final String? uid;
  final bool minimal;
  final TextStyle? labelStyle;
  final Function()? onDeleted;
  final String? avatarPrefix;

  @override
  State<UserChip> createState() => _UserChipState();
}

class _UserChipState extends State<UserChip> {
  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) return const SizedBox(width: 0, height: 0);
    final stateUsers = Provider.of<StateUsers>(context, listen: true);
    final user = stateUsers.getUser(widget.uid!);
    String label = user.id!;
    if (user.username != null) label = user.username!;
    if (user.name.isNotEmpty) label = user.name;
    if (widget.minimal) return Text(label, style: widget.labelStyle);
    String? url = user.avatar;
    if (widget.avatarPrefix != null && user.avatar != null) {
      url = '${widget.avatarPrefix}/${user.avatar}';
    }
    return Chip(
      avatar: UserAvatar(
        avatar: url,
        firstName: user.firstName,
        lastName: user.lastName,
        name: user.name,
        presence: user.presence,
      ),
      label: Text(label),
      onDeleted: widget.onDeleted,
    );
  }
}
