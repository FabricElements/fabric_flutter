library fabric_flutter;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../state/state_alert.dart';
import '../state/state_analytics.dart';
import '../state/state_dynamic_links.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';

class InitApp extends StatelessWidget {
  const InitApp({
    Key? key,
    required this.child,
    required this.providers,
    this.loader,
    this.notifications = false,
    this.links = false,
  }) : super(key: key);

  final Widget child;
  final List<SingleChildWidget>? providers;
  final Widget? loader;
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
          // WidgetsFlutterBinding.ensureInitialized();

          /// Call App States after MultiProvider is called
          final stateUser = Provider.of<StateUser>(context, listen: false);

          /// Init User
          stateUser.init();
          final stateNotifications =
              Provider.of<StateNotifications>(context, listen: false);
          final stateDynamicLinks =
              Provider.of<StateDynamicLinks>(context, listen: false);

          /// Refresh auth state
          _refreshAuth(User? userObject) async {
            String? uid = userObject?.uid;
            if (uid != null) {
              if (notifications && kReleaseMode) {
                stateNotifications.uid = uid;
                stateNotifications.init();
              }
            } else {
              if (notifications && kReleaseMode) {
                stateNotifications.clear(); // Stop notifications when sign out
              }
            }
            return null;
          }

          stateUser.streamUser
              .listen((User? userObject) => _refreshAuth(userObject));

          /// Dynamic Links
          if (links) {
            try {
              stateDynamicLinks.init();
            } catch (e) {
              if (kDebugMode) print(e);
            }
          }

          return child;
        },
      ),
    );
  }
}
