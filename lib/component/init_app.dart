import 'package:fabric_flutter/helper/log_color.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../state/state_alert.dart';
import '../state/state_analytics.dart';
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
  });

  final List<SingleChildWidget> providers;
  final Widget child;
  final bool notifications;

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
        ChangeNotifierProvider(create: (context) => StateNotifications()),
        ChangeNotifierProvider(create: (context) => StateUsers()),
      ],
      child: InitAppChild(
        notifications: notifications,
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
  });

  final Widget child;
  final bool notifications;

  @override
  Widget build(BuildContext context) {
    /// Call App States after MultiProvider is called
    final stateUser = Provider.of<StateUser>(context);
    final theme = Theme.of(context);

    /// Init User
    stateUser.init();

    final stateNotifications =
        Provider.of<StateNotifications>(context, listen: false);
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);

    /// Define default error message
    stateUser.onError = (String? e) => (e != null)
        ? debugPrint(LogColor.error('StateUser.onError: $e'))
        : null;

    /// Set user id for analytics
    if (stateUser.userStatus.signedIn) {
      try {
        stateAnalytics.analytics?.setUserId(id: stateUser.userStatus.uid);
      } catch (error) {
        debugPrint(LogColor.error('FirebaseAnalytics error: $error'));
      }
    }
    try {
      if (stateUser.userStatus.signedIn) {
        if (notifications) {
          stateNotifications.token = stateUser.serialized.fcm;
          stateNotifications.uid = stateUser.userStatus.uid;
          stateNotifications.init();
          stateNotifications.getUserToken().catchError((e) {
            debugPrint(
                LogColor.error('StateNotifications.getUserToken() Error: $e'));
          });
        }
      } else {
        if (notifications && !kDebugMode) {
          // Stop notifications when sign out
          stateNotifications.clear();
        }
      }
    } catch (error) {
      debugPrint(LogColor.error('InitAppChild error: $error'));
    }

    /// Check if user is ready
    if (!stateUser.userStatus.ready) {
      debugPrint(LogColor.warning('User not ready'));
      return Container(
        color: theme.colorScheme.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    debugPrint(LogColor.success('User ready'));

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
