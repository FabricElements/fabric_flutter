import 'package:fabric_flutter/component.dart';
import 'package:fabric_flutter/view/view_featured.dart';
import 'package:flutter/material.dart';

class InvitationExample extends StatelessWidget {
  InvitationExample({Key? key, required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  void _inviteUser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return UserInvite(
          user: null,
          data: {},
          showPhone: true
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ViewFeatured(
        image: "https://source.unsplash.com/random",
        headline: "Open the Invitation Component from the button below!",
        actionLabel: "OPEN INVITATION",
        onPressed: () {
          _inviteUser(context);
        },
        firstGradientAnimationColor: Colors.grey.shade900,
        secondGradientAnimationColor: Colors.grey.shade900,
        thirdGradientAnimationColor: Colors.grey.shade900,
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
