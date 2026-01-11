import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../helper/log_color.dart';
import '../serialized/user_status.dart';
import '../state/state_alert.dart';
import '../state/state_analytics.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';
import '../state/state_users.dart';
import '../state/state_view_auth.dart';

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
        ChangeNotifierProvider(create: (context) => StateViewAuth()),
        ChangeNotifierProvider(create: (context) => StateGlobal()),
        ChangeNotifierProvider(create: (context) => StateUser()),
        ListenableProvider(create: (context) => StateAlert()),
        ChangeNotifierProvider(create: (context) => StateAnalytics()),
        ChangeNotifierProvider(create: (context) => StateNotifications()),
        ChangeNotifierProvider(create: (context) => StateUsers()),
      ],
      child: InitAppChild(notifications: notifications, child: child),
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
    final theme = Theme.of(context);

    /// Call App States after MultiProvider is called
    final stateUser = Provider.of<StateUser>(context, listen: false);
    final stateNotifications = Provider.of<StateNotifications>(
      context,
      listen: false,
    );
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);

    /// Define default error message
    stateUser.onError = (String? e) => (e != null)
        ? debugPrint(LogColor.error('StateUser.onError: $e'))
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      /// Init User
      stateUser.init();
    });

    stateUser.streamStatus.listen((status) {
      /// Set user id for analytics
      if (status.signedIn) {
        try {
          stateAnalytics.analytics?.setUserId(id: status.uid);
        } catch (error) {
          debugPrint(LogColor.error('FirebaseAnalytics error: $error'));
        }
      }
      try {
        if (status.signedIn) {
          if (notifications) {
            stateNotifications.token = stateUser.serialized.fcm;
            stateNotifications.uid = status.uid;
            stateNotifications.init();
            stateNotifications.getUserToken().catchError((e) {
              debugPrint(
                LogColor.error('StateNotifications.getUserToken() Error: $e'),
              );
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
    });

    final loadingWidget = Container(
      color: theme.colorScheme.surface,
      child: const Center(child: CircularProgressIndicator()),
    );

    /// Return child component
    return GestureDetector(
      onTap: () {
        /// Close keyboard when tap outside input
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.requestFocus(FocusNode());
        }
      },
      child: StreamBuilder<UserStatus>(
        stream: stateUser.streamStatus,
        initialData: stateUser.userStatus,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return loadingWidget;
          }
          final status = snapshot.data!;
          if (!status.ready) {
            return loadingWidget;
          }
          return child;
        },
      ),
    );
  }
}
