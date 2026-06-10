import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state_users.dart';
import 'user_avatar.dart';

/// UserChip displays a User's profile name and avatar
class UserChip extends StatefulWidget {
  /// Creates a chip that resolves user metadata from [StateUsers].
  ///
  /// This widget exists so callers can pass a user id and let the shared state
  /// layer handle live updates to names, avatars, and presence information.
  const UserChip({
    super.key,
    required this.uid,
    this.minimal = false,
    this.labelStyle,
    this.onDeleted,
    this.avatarPrefix,
  });

  /// The user identifier looked up in [StateUsers].
  final String? uid;

  /// Shows only the resolved text label when `true`.
  final bool minimal;

  /// Overrides the text style used by the minimal label variant.
  final TextStyle? labelStyle;

  /// Called when the chip's delete affordance is pressed.
  final Function()? onDeleted;

  /// Prepends a base path to avatar image names when one is required.
  final String? avatarPrefix;

  /// Creates state that rebuilds when user data changes in the provider.
  @override
  State<UserChip> createState() => _UserChipState();
}

/// Resolves user state into the visual chip representation used by [UserChip].
class _UserChipState extends State<UserChip> {
  /// Builds either a compact text label or a full chip, depending on [UserChip.minimal].
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
