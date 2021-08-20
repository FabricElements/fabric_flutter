import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
// import 'package:rive/rive.dart';

/// LoadingScreen is a preview screen when is loading any content.
class LoadingScreen extends StatelessWidget {
  LoadingScreen({
    Key? key,
    this.parent = false,
  }) : super(key: key);
  final bool parent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: parent ? AppBar() : null,
      body: Container(
        color: Colors.teal.shade500,
        child: Center(
          // child: RiveAnimation.asset(
          //   "assets/loading.riv",
          //   fit: BoxFit.contain,
          //   alignment: Alignment.center,
          // ),
          child: FlareActor(
            "assets/loading.flr",
            alignment: Alignment.center,
            fit: BoxFit.contain,
            animation: "Loading",
          ),
        ),
      ),
    );
  }
}
