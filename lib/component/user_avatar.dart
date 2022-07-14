library fabric_flutter;

import 'package:flutter/material.dart';

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
    required this.name,
  }) : super(key: key);
  final String? avatar;
  final String? name;

  String _acronym(String? text) {
    if (text == null) {
      return '';
    }
    String finalText = '';
    var matches = text.split(' ');
    if (matches.isEmpty) {
      return '?';
    }
    int totalMatches = matches.length > 2 ? matches.length : matches.length;
    for (int i = 0; i < totalMatches; i++) {
      try {
        String match = matches[i][0];
        finalText += match;
      } catch (error) {
        //
      }
    }
    if (finalText.isEmpty) {
      return '?';
    }
    finalText = finalText.toUpperCase();
    return finalText;
  }

  @override
  Widget build(BuildContext context) {
    if (avatar != null) {
      return CircleAvatar(
        backgroundImage: NetworkImage(avatar!),
        backgroundColor: Colors.grey.shade100,
      );
    }
    if (name != null) {
      String finalName = _acronym(name);
      return CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: Text(finalName),
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
