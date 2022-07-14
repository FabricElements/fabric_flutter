library fabric_flutter;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../serialized/user_data.dart';
import '../state/state_alert.dart';
import '../state/state_analytics.dart';
import '../state/state_dynamic_links.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';

class InitApp extends StatelessWidget {
  const InitApp({
    Key? key,
    required this.providers,
    required this.child,
    this.notifications = false,
    this.links = false,
  }) : super(key: key);

  final List<SingleChildWidget>? providers;
  final Widget child;
  final bool notifications;
  final bool links;

  @override
  Widget build(BuildContext context) {
    /// Init Providers
    List<SingleChildWidget> allProviders = providers ?? [];
    allProviders.addAll([
      ChangeNotifierProvider(create: (context) => StateUser()),
      ChangeNotifierProvider(create: (context) => StateAnalytics()),
      ChangeNotifierProvider(create: (context) => StateDynamicLinks()),
      ChangeNotifierProvider(create: (context) => StateNotifications()),
      ChangeNotifierProvider(create: (context) => StateGlobal()),
      ChangeNotifierProvider(create: (context) => StateAlert()),
    ]);

    /// Run on emulators
    if (kDebugMode) {
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    }
    return MultiProvider(
      providers: allProviders,
      child: Builder(
        builder: (context) {
          /// Call App States after MultiProvider is called
          final stateUser = Provider.of<StateUser>(context, listen: false);
          final stateNotifications =
              Provider.of<StateNotifications>(context, listen: false);
          final stateDynamicLinks =
              Provider.of<StateDynamicLinks>(context, listen: false);
          final alert = Provider.of<StateAlert>(context, listen: false);

          /// Define default error message
          stateUser.onError = (String? e) => (e != null)
              ? alert.show(AlertData(
                  title: e,
                  type: AlertType.critical,
                  clear: true,
                  brightness: Brightness.dark,
                ))
              : null;

          /// Refresh auth state
          _refreshAuth(UserStatus? value) async {
            String? uid = value?.uid;
            if (uid != null) {
              if (notifications && kDebugMode) {
                stateNotifications.uid = uid;
                stateNotifications.init();
              }
            } else {
              if (notifications && kDebugMode) {
                stateNotifications.clear(); // Stop notifications when sign out
              }
            }
            return null;
          }

          stateUser.streamStatus.listen((value) => _refreshAuth(value));

          /// Dynamic Links
          if (links) {
            try {
              stateDynamicLinks.init();
            } catch (e) {
              if (kDebugMode) print(e);
            }
          }

          /// Init User
          stateUser.init();

          /// Return child component
          return child;
        },
      ),
    );
  }
}
