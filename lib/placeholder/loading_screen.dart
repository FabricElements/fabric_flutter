import 'package:flutter/material.dart';

import '../helper/utils.dart';

/// LoadingScreen is a preview screen when is loading any content.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.parent = false, this.log = false});

  final bool parent;
  final bool log;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    // Use system theme colors
    // final brightness = MediaQuery.of(context).platformBrightness;
    // if (brightness == Brightness.dark) {
    //   print('Using dark theme');
    //   theme = theme.copyWith(colorScheme: ThemeData.dark().colorScheme);
    // } else {
    //   print('Using light theme');
    //   theme = theme.copyWith(colorScheme: ThemeData.light().colorScheme);
    // }
    // print(theme.colorScheme.surface);
    // print('--------------------------------');

    if (log) {
      Utils.getParentWidgetName(context);
    }

    return Container(
      color: theme.colorScheme.surface,
      height: double.maxFinite,
      width: double.maxFinite,
      child: Column(
        children: [
          if (parent) AppBar(),
          Spacer(),
          SizedBox(
            width: kToolbarHeight,
            height: kToolbarHeight,
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onSurface,
              ),
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
