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
  _UserChipState createState() => _UserChipState();
}

class _UserChipState extends State<UserChip> {
  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) return const SizedBox(width: 0, height: 0);
    StateUser stateUser = Provider.of<StateUser>(context);
    final user = stateUser.getUser(widget.uid!);
    String label = user.id!;
    if (user.username != null) label = user.username!;
    if (user.name.isNotEmpty) label = user.name;
    if (widget.minimal) return Text(label, style: widget.labelStyle);
    Widget avatar = CircleAvatar(
      backgroundImage: NetworkImage(user.avatar),
      backgroundColor: Colors.grey.shade900,
    );
    return Chip(
      avatar: avatar,
      label: Text(label),
    );
  }
}
