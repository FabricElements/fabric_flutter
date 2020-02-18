import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helpers/state-dynamic-links.dart';
import '../helpers/state-notifications.dart';

/// This widget has to go on the top of your app
class TopApp extends StatelessWidget with WidgetsBindingObserver {
  TopApp({
    Key key,
    @required this.child,
    this.notifications = false,
    this.links = false,
  }) : super(key: key);
  final Widget child;
  final bool notifications;
  final bool links;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addObserver(this);
    String uid;
    StateNotifications stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    StateDynamicLinks stateDynamicLinks =
        Provider.of<StateDynamicLinks>(context, listen: false);
    if (links) {
      stateDynamicLinks.init();
    }
    if (notifications) {
      stateNotifications.init();
    }
    try {
      FirebaseAuth.instance.onAuthStateChanged.listen(
        (FirebaseUser userObject) async {
          uid = userObject?.uid ?? null;
          if (notifications) {
            if (uid != null) {
              stateNotifications.uid = uid;
            } else {
              stateNotifications.clear(); // Stop notifications when sign out
            }
          }
        },
      );
    } catch (error) {
      print(error);
    }
    return child;
  }
}
