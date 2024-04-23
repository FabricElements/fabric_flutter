import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/state_user.dart';
import 'print_color.dart';

class RedirectApp {
  RedirectApp({
    required this.context,
    // Protect views from redirection if the user is not an admin
    required this.protected,
  });

  final List<String> protected;
  final BuildContext context;

  /// Redirect page
  void toView({
    String? path,
    Map<String, dynamic>? arguments,
  }) {
    final stateUser = Provider.of<StateUser>(context, listen: false);
    try {
      if (path != null && path.isNotEmpty && path.startsWith('/')) {
        if (!stateUser.admin && protected.contains(path)) return;
        Navigator.of(context).popAndPushNamed(path, arguments: arguments);
      }
    } catch (error) {
      debugPrint(PrintColor.error(error));
    }
  }

  void link({
    Uri? link,
  }) {
    if (link != null) {
      toView(
        path: link.path,
        arguments: link.queryParameters,
      );
    }
  }
}
