import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/state_user.dart';
import 'log_color.dart';

/// Handles guarded in-app navigation based on the current user's role.
///
/// This helper centralizes the check that prevents non-admin users from
/// opening routes listed in [protected], which keeps redirection logic out of
/// individual widgets. It is intentionally lightweight and silently ignores
/// invalid or blocked destinations.
class RedirectApp {
  /// Creates a navigation helper bound to a specific [BuildContext].
  RedirectApp({
    required this.context,
    // Protect views from redirection if the user is not an admin
    required this.protected,
  });

  /// Lists route names that should only be reachable by admin users.
  final List<String> protected;

  /// Provides access to [Navigator] and the current [StateUser].
  final BuildContext context;

  /// Redirects to [path] when it is valid and allowed for the current user.
  ///
  /// The helper only navigates to non-empty absolute route names that start
  /// with `/`. When a non-admin user tries to open a protected route, the call
  /// is ignored to avoid exposing restricted screens. Any navigation error is
  /// logged instead of being rethrown so caller code can stay simple.
  void toView({String? path, Map<String, dynamic>? arguments}) {
    final stateUser = Provider.of<StateUser>(context, listen: false);
    try {
      if (path != null && path.isNotEmpty && path.startsWith('/')) {
        if (!stateUser.admin && protected.contains(path)) return;
        Navigator.of(context).popAndPushNamed(path, arguments: arguments);
      }
    } catch (error) {
      debugPrint(LogColor.error(error));
    }
  }

  /// Redirects using the path and query parameters from [link].
  ///
  /// This is useful for deep-link handling because it reuses [toView] and keeps
  /// the same authorization and validation rules in one place. A `null` link is
  /// ignored.
  void link({Uri? link}) {
    if (link != null) {
      toView(path: link.path, arguments: link.queryParameters);
    }
  }
}
