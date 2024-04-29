import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
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
    super.key,
    this.providers = const [],
    required this.child,
    this.notifications = false,
    this.links = false,
  });

  final List<SingleChildWidget> providers;
  final Widget child;
  final bool notifications;
  final bool links;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      /// Init Providers
      providers: [
        ...providers,
        ChangeNotifierProvider(create: (context) => StateGlobal()),
        ChangeNotifierProvider(create: (context) => StateUser()),
        ListenableProvider(create: (context) => StateAlert()),
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
    super.key,
    required this.child,
    this.notifications = false,
    this.links = false,
  });

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
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);

    /// Define default error message
    stateUser.onError = (String? e) => (e != null)
        ? alert.show(AlertData(
            title: e,
            type: AlertType.critical,
            clear: true,
            duration: 3,
          ))
        : null;

    try {
      stateUser.streamStatus.listen(
        (value) {
          try {
            stateAnalytics.analytics?.setUserId(id: value.uid);
          } catch (error) {
            debugPrint('FirebaseAnalytics error: $error');
          }
          if (value.signedIn) {
            if (notifications) {
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
      if (links && !kIsWeb && !kDebugMode) {
        stateDynamicLinks.init();
      }
    } catch (error) {
      alert.show(AlertData(
        title: error.toString(),
        type: AlertType.warning,
        clear: true,
        duration: 3,
      ));
    }

    /// Init User
    stateUser.init();

    /// Return child component
    return GestureDetector(
      onTap: () {
        /// Close keyboard when tap outside input
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.requestFocus(FocusNode());
        }
      },
      child: child,
    );
  }
}
