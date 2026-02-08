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
          CircularProgressIndicator.adaptive(
            value: null,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.surface,
            ),
            backgroundColor: theme.colorScheme.onSurface,
          ),
          Spacer(),
        ],
      ),
    );
  }
}
