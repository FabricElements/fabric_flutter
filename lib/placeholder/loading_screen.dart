import 'package:flutter/material.dart';

import '../helper/utils.dart';

/// Displays a full-screen loading indicator with an adaptive spinner.
///
/// [LoadingScreen] provides a consistent loading experience across platforms,
/// using Material or Cupertino styling based on the device. It's commonly used
/// as a placeholder while waiting for asynchronous data or authentication state
/// to resolve.
class LoadingScreen extends StatelessWidget {
  /// Creates a loading screen.
  ///
  /// The [parent] flag determines whether to include an AppBar at the top,
  /// which can help maintain visual consistency with parent layouts. The [log]
  /// flag enables debugging output to trace widget hierarchy.
  const LoadingScreen({super.key, this.parent = false, this.log = false});

  /// Whether to include an AppBar at the top of the loading screen.
  ///
  /// Set to true when the loading screen replaces content that normally has
  /// an AppBar, maintaining consistent layout height.
  final bool parent;

  /// Whether to log the parent widget hierarchy for debugging purposes.
  ///
  /// When true, prints the widget tree information to help trace rendering issues.
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
