// import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../state/state_alert.dart';
import '../state/state_analytics.dart';
import '../state/state_dynamic_links.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';
import '../state/state_users.dart';

class InitApp extends StatelessWidget {
  const InitApp({
    Key? key,
    this.providers = const [],
    required this.child,
    this.notifications = false,
    this.links = false,
  }) : super(key: key);

  final List<SingleChildWidget> providers;
  final Widget child;
  final bool notifications;
  final bool links;

  @override
  Widget build(BuildContext context) {
    /// Run on emulators
    // if (kDebugMode) {
    //   FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    //   // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    // }
    return MultiProvider(
      /// Init Providers
      providers: [
        ...providers,
        ChangeNotifierProvider(create: (context) => StateGlobal()),
        ChangeNotifierProvider(create: (context) => StateUser()),
        ChangeNotifierProvider(create: (context) => StateAlert()),
        ChangeNotifierProvider(create: (context) => StateAnalytics()),
        ChangeNotifierProvider(create: (context) => StateDynamicLinks()),
        ChangeNotifierProvider(create: (context) => StateNotifications()),
        ChangeNotifierProvider(create: (context) => StateUsers()),
      ],
      child: InitAppChild(
        notifications: notifications,
        links: links,
        child: child,
      ),
    );
  }
}

class InitAppChild extends StatelessWidget {
  const InitAppChild({
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
    /// Call App States after MultiProvider is called
    final stateUser = Provider.of<StateUser>(context, listen: false);
    final stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    final stateDynamicLinks =
        Provider.of<StateDynamicLinks>(context, listen: false);
    final alert = Provider.of<StateAlert>(context, listen: false);
    alert.context = context;

    /// Define default error message
    stateUser.onError = (String? e) => (e != null)
        ? alert.show(AlertData(
            title: e,
            type: AlertType.critical,
            clear: true,
            brightness: Brightness.dark,
            duration: 3,
          ))
        : null;

    try {
      stateUser.streamStatus.listen(
        (value) {
          if (value.signedIn) {
            if (notifications && !kDebugMode) {
              stateNotifications.uid = value.uid;
              stateNotifications.init();
            }
          } else {
            if (notifications && !kDebugMode) {
              // Stop notifications when sign out
              stateNotifications.clear();
            }
          }
        },
      );

      /// Dynamic Links
      if (links && !kDebugMode) {
        stateDynamicLinks.init();
      }
    } catch (error) {
      alert.show(AlertData(
        title: error.toString(),
        type: AlertType.warning,
        clear: true,
        brightness: Brightness.dark,
        duration: 3,
      ));
    }

    /// Init User
    stateUser.init();

    /// Return child component
    return child;
  }
}
