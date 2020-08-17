import 'package:fabric_flutter/helpers/state-dynamic-links.dart';
import 'package:fabric_flutter/helpers/state-notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    StateNotifications stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    StateDynamicLinks stateDynamicLinks =
        Provider.of<StateDynamicLinks>(context, listen: false);
    String uid;

    try {
      FirebaseAuth.instance.onAuthStateChanged.listen(
        (FirebaseUser userObject) async {
          await Future.delayed(Duration(seconds: 1));
          uid = userObject?.uid ?? null;
          if (uid != null) {
            if (links) {
              stateDynamicLinks.init();
            }
            if (notifications) {
              stateNotifications.uid = uid;
              stateNotifications.init();
            }
          } else {
            stateNotifications.clear(); // Stop notifications when sign out
          }
        },
      );
    } catch (error) {
      print(error);
    }

    return child;
  }
}
