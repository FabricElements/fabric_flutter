import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../state/state_analytics.dart';
import '../state/state_api.dart';
import '../state/state_document.dart';
import '../state/state_dynamic_links.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final Future<FirebaseApp> _initialization = Firebase.initializeApp();

class InitApp extends StatelessWidget {
  InitApp({
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

  emulators() async {
    if (kDebugMode) {
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    }
  }

  @override
  Widget build(BuildContext context) {
    emulators();

    /// Init Providers
    List<SingleChildWidget> _providers = providers ?? [];
    _providers.addAll([
      ChangeNotifierProvider(create: (context) => StateAnalytics()),
      ChangeNotifierProvider(create: (context) => StateAPI()),
      ChangeNotifierProvider(create: (context) => StateDocument()),
      ChangeNotifierProvider(create: (context) => StateDynamicLinks()),
      ChangeNotifierProvider(create: (context) => StateGlobal()),
      ChangeNotifierProvider(create: (context) => StateNotifications()),
      ChangeNotifierProvider(create: (context) => StateUser()),
    ]);
    Widget loadingApp = Container(color: Colors.grey.shade500);

    return MultiProvider(
      providers: _providers,
      child: FutureBuilder(
        // Initialize FlutterFire:
        future: _initialization,
        builder: (context, snapshot) {
          // Check for errors
          if (snapshot.hasError) {
            print(snapshot.error.toString());
            print("_initialization load error");
            return loadingApp;
          }

          /// Call App States after MultiProvider is called
          final stateNotifications =
              Provider.of<StateNotifications>(context, listen: false);
          final stateDynamicLinks =
              Provider.of<StateDynamicLinks>(context, listen: false);
          final stateUser = Provider.of<StateUser>(context, listen: false);
          StateGlobal stateGlobal =
              Provider.of<StateGlobal>(context, listen: false);
          stateUser.init();

          /// Refresh auth state
          _refreshAuth(User? userObject) async {
            String? uid = userObject?.uid ?? null;
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
            return null;
          }

          _auth
              .userChanges()
              .listen((User? userObject) => _refreshAuth(userObject));

          /// Dynamic Links
          if (links) {
            try {
              stateDynamicLinks.init();
            } catch (e) {
              print(e);
            }
          }

          // Otherwise, show something whilst waiting for initialization to complete
          if (snapshot.connectionState != ConnectionState.done)
            return loadingApp;

          return child;
        },
      ),
    );
  }
}
