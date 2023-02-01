import 'package:flutter/material.dart';

import '../helper/utils.dart';
import '../serialized/user_data.dart';

/// UserAvatar shows the image and the name of the users in profile sections.
///
/// [avatar] This is a parameter of the image in the widget.
/// [name] This is a parameter of the name in the widget.
/// UserAvatar(
///   avatar: imageUrl,
///   name: 'Jeffery',
/// );
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    Key? key,
    required this.avatar,
    this.name,
    this.firstName,
    this.lastName,
    this.presence,
  }) : super(key: key);
  final String? avatar;
  final String? name;
  final String? firstName;
  final String? lastName;
  final UserPresence? presence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final color = theme.colorScheme.primary;
    String abbreviation = Utils.nameAbbreviation(
      firstName: firstName,
      lastName: lastName,
    );
    Widget avatarContainer = CircleAvatar(
      backgroundColor: Colors.grey.shade100,
      child: Icon(
        Icons.person,
        color: color,
      ),
    );
    if (avatar != null) {
      avatarContainer = CircleAvatar(
        backgroundImage: NetworkImage(avatar!),
        backgroundColor: color,
      );
    } else if (abbreviation.isNotEmpty) {
      avatarContainer = CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: Text(
          abbreviation,
          style: textTheme.titleMedium?.copyWith(color: color),
        ),
      );
    }

    /// Return only avatar if presence is null
    if (presence == null) return avatarContainer;

    /// Get user status presence
    Color statusColor = Colors.transparent;
    switch (presence) {
      case UserPresence.active:
        statusColor = Colors.green;
        break;
      case UserPresence.inactive:
        statusColor = Colors.deepOrange;
        break;
      case UserPresence.away:
        statusColor = Colors.transparent;
        break;
      default:
    }
    final presenceWidget = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: 1 / 1,
      child: Stack(
        children: [
          avatarContainer,
          Positioned(
            right: 0,
            top: 0,
            child: presenceWidget,
          ),
        ],
      ),
    );
  }
}
