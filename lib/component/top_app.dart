import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state_dynamic_links.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';

/// This widget has to go on the top of your app
class TopApp extends StatelessWidget with WidgetsBindingObserver {
  TopApp({
    Key? key,
    required this.child,
    this.notifications = false,
    this.links = false,
  }) : super(key: key);
  final Widget child;
  final bool notifications;
  final bool links;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance!.addObserver(this);
    StateNotifications stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    StateDynamicLinks stateDynamicLinks =
        Provider.of<StateDynamicLinks>(context, listen: false);
    StateUser stateUser = Provider.of<StateUser>(context, listen: false);
    final FirebaseAuth _auth = FirebaseAuth.instance;

    /// Refresh auth state
    _refreshAuth(User? userObject) async {
      String? uid = userObject?.uid ?? null;
      stateUser.id = uid;
      stateUser.object = userObject ?? null;
      if (uid != null) {
        if (notifications) {
          stateNotifications.uid = uid;
          stateNotifications.init();
        }
      } else {
        if (notifications) {
          stateNotifications.clear(); // Stop notifications when sign out
        }
      }
    }

    _auth
        .authStateChanges()
        .listen((User? userObject) => _refreshAuth(userObject));

    /// Dynamic Links
    if (links) {
      try {
        stateDynamicLinks.init();
      } catch (e) {
        print(e);
      }
    }

    // return StreamBuilder(
    //   stream: _auth.authStateChanges(),
    //   builder: (context, snapshot) {
    //     return child;
    //   },
    // );

    return child;
  }
}
