import 'package:flutter/material.dart';

import '../helper/utils.dart';

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
  }) : super(key: key);
  final String? avatar;
  final String? name;
  final String? firstName;
  final String? lastName;

  @override
  Widget build(BuildContext context) {
    if (avatar != null) {
      return CircleAvatar(
        backgroundImage: NetworkImage(avatar!),
        backgroundColor: Colors.grey.shade100,
      );
    }
    String abbreviation = Utils.nameAbbreviation(
      name: name,
      firstName: firstName,
      lastName: lastName,
    );
    if (abbreviation.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: Text(abbreviation),
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.grey.shade100,
      child: Icon(
        Icons.person,
        color: Colors.grey.shade500,
      ),
    );
  }
}
