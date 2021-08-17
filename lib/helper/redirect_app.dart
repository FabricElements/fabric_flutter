import 'package:fabric_flutter/state/state_user.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

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
    required Map<String, dynamic> params,
  }) async {
    StateUser stateUser = Provider.of<StateUser>(context, listen: false);
    try {
      if (path != null && path.isNotEmpty && path.startsWith("/")) {
        if (!stateUser.admin && protected.contains(path)) return;
        await Future.delayed(Duration(milliseconds: 100));
        Navigator.of(context).popAndPushNamed(path);
      }
    } catch (error) {
      print(error);
    }
  }

  void link({
    Uri? link,
  }) {
    if (link != null) {
      final Map<String, String>? params = link.queryParameters;
      // Format the child map
      Map<String, String> _params = params ?? {};
      toView(
        path: link.path,
        params: _params,
      );
    }
  }
}
