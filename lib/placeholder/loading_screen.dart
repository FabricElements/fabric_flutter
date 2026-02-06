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
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      theme.copyWith(colorScheme: ThemeData.dark().colorScheme);
    } else {
      theme.copyWith(colorScheme: ThemeData.light().colorScheme);
    }

    if (log) {
      Utils.getParentWidgetName(context);
    }

    return Theme(
      data: theme,
      child: Container(
        color: theme.scaffoldBackgroundColor,
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
                  theme.colorScheme.primary,
                ),
              ),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
