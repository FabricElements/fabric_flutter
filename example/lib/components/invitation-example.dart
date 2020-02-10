import 'package:fabric_flutter/components.dart';
import 'package:flutter/material.dart';

class InvitationExample extends StatelessWidget {
  InvitationExample({Key key, @required this.scaffoldKey}) : super(key: key);
  final GlobalKey<ScaffoldState> scaffoldKey;

  void _inviteUser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return UserInvite(
          user: null,
          info: {},
          roles: {"admin": "admin"},
          showPhone: true,
          alert: (message) {
            print("Invitation message: $message");
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FeaturedView(
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
