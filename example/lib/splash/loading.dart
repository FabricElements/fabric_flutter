import 'package:flutter/material.dart';

/// LoadingScreen is a preview screen when is loading any content.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    Key? key,
    this.parent = false,
  }) : super(key: key);
  final bool parent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: parent ? AppBar() : null,
      body: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading',
          ),
        ),
      ),
    );
  }
}
