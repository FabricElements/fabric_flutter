import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../helper/log_color.dart';
import '../serialized/user_status.dart';
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
        ChangeNotifierProvider(create: (context) => StateNotifications()),
        ChangeNotifierProvider(create: (context) => StateUser()),
        ChangeNotifierProvider(create: (context) => StateAnalytics()),
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
    final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
    ThemeData theme = Theme.of(context);
    // Use system theme colors
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      theme.copyWith(colorScheme: ThemeData.dark().colorScheme);
    } else {
      theme.copyWith(colorScheme: ThemeData.light().colorScheme);
    }

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

    stateUser.streamStatus.listen((status) async {
      /// Set user id for analytics
      if (status.signedIn) {
        try {
          stateAnalytics.analytics?.setUserId(id: status.uid);
        } catch (error) {
          debugPrint(LogColor.error('FirebaseAnalytics error: $error'));
        }
      }

      /// Init Notifications
      if (notifications) {
        try {
          if (status.signedIn) {
            /// Wait 3 seconds to ensure FCM token is ready
            await Future.delayed(const Duration(seconds: 3));
            stateNotifications.token = stateUser.serialized.fcm;
            stateNotifications.uid = status.uid;
            stateNotifications.init();
            stateNotifications.getUserToken().catchError((e) {
              debugPrint(
                LogColor.error('StateNotifications.getUserToken() Error: $e'),
              );
            });
          } else {
            if (!kDebugMode) {
              // Stop notifications when sign out
              stateNotifications.clear();
            }
          }
        } catch (error) {
          debugPrint(LogColor.error('InitAppChild error: $error'));
        }
      }
    });

    /// Loading widget
    final loadingWidget = Theme(
      data: theme,
      child: Container(
        color: theme.colorScheme.surface,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      /// Init App States
      stateGlobal.init();
      stateUser.init();
    });

    /// Return child component
    return StreamBuilder<UserStatus>(
      key: Key('init-app-user-status-stream-builder'),
      stream: stateUser.streamStatus,
      initialData: stateUser.userStatus,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return loadingWidget;
          default:
        }
        if (snapshot.data == null) {
          return loadingWidget;
        }
        final status = snapshot.data!;
        final notReady = !status.ready;
        if (notReady) return loadingWidget;

        /// Set user id for analytics
        if (status.signedIn) {
          try {
            stateAnalytics.analytics?.setUserId(id: status.uid);
          } catch (error) {
            debugPrint(LogColor.error('FirebaseAnalytics error: $error'));
          }
        }

        /// Init Notifications
        if (notifications) {
          try {
            if (status.signedIn) {
              /// Wait 3 seconds to ensure FCM token is ready
              // await Future.delayed(const Duration(seconds: 3));
              stateNotifications.token = stateUser.serialized.fcm;
              stateNotifications.uid = status.uid;
              stateNotifications.init();
              stateNotifications.getUserToken().catchError((e) {
                debugPrint(
                  LogColor.error('StateNotifications.getUserToken() Error: $e'),
                );
              });
            } else {
              if (!kDebugMode) {
                // Stop notifications when sign out
                stateNotifications.clear();
              }
            }
          } catch (error) {
            debugPrint(LogColor.error('InitAppChild error: $error'));
          }
        }
        return child;
      },
    );
  }
}
