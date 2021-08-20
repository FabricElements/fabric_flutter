import 'package:flutter/material.dart';

/// LoadingScreen is a preview screen when is loading any content.
class LoadingScreen extends StatelessWidget {
  LoadingScreen({
    Key? key,
    this.parent = false,
  }) : super(key: key);
  final bool parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: parent ? AppBar() : null,
      body: Container(
        color: theme.primaryColor,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              CircularProgressIndicator(
                semanticsLabel: 'Linear progress indicator',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
