import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helpers/state-notifications.dart';

/// This widget has to go on the top of your app
class TopApp extends StatelessWidget with WidgetsBindingObserver {
  TopApp({
    Key key,
    @required this.child,
    this.notifications = false,
  }) : super(key: key);
  final Widget child;
  final bool notifications;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addObserver(this);
    String uid;
    StateNotifications stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
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
    return LimitedBox(
      child: MediaQuery(
        data: MediaQueryData.fromWindow(WidgetsBinding.instance.window),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(primary: true, body: child),
        ),
      ),
    );
  }
}
