import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';

/// LoadingScreen is a preview screen when is loading any content.
class EmptyScreen extends StatelessWidget {
  EmptyScreen({
    Key? key,
    this.parent = false,
  }) : super(key: key);
  final bool parent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FlareActor(
        "assets/empty.flr",
        alignment: Alignment.center,
        fit: BoxFit.contain,
        animation: "cart",
      ),
    );
  }
}
