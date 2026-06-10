import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../helper/log_color.dart';
import '../placeholder/loading_screen.dart';
import '../serialized/user_status.dart';
import '../state/state_analytics.dart';
import '../state/state_global.dart';
import '../state/state_notifications.dart';
import '../state/state_user.dart';
import '../state/state_users.dart';
import '../state/state_view_auth.dart';

/// Installs the core application providers required by the component library.
///
/// Wrapping an app with [InitApp] ensures that authentication, analytics,
/// notifications, and shared global state are available before descendant
/// widgets begin reading them.
class InitApp extends StatelessWidget {
  /// Creates the provider bootstrap used by Fabric Flutter widgets.
  const InitApp({
    super.key,
    this.providers = const [],
    required this.child,
    this.notifications = false,
  });

  /// Additional providers inserted ahead of the default Fabric providers.
  final List<SingleChildWidget> providers;

  /// The application subtree that should receive the initialized providers.
  final Widget child;

  /// Enables notification setup once the signed-in user becomes available.
  final bool notifications;

  /// Builds the provider tree and hands off lifecycle work to [InitAppChild].
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

/// Finalizes app bootstrap after the provider tree has been installed.
///
/// This widget delays initialization work until provider lookups are safe, then
/// coordinates theme selection, user-state startup, and optional notification
/// wiring before revealing the application child.
class InitAppChild extends StatelessWidget {
  /// Creates the post-provider bootstrap widget.
  const InitAppChild({
    super.key,
    required this.child,
    this.notifications = false,
  });

  /// The application subtree shown once bootstrap work is complete.
  final Widget child;

  /// Enables notification lifecycle management for signed-in users.
  final bool notifications;

  /// Starts app services and returns either the loading screen or the real child.
  @override
  Widget build(BuildContext context) {
    final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
    ThemeData theme = Theme.of(context);
    // Use system theme colors
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      theme = theme.copyWith(colorScheme: ThemeData.dark().colorScheme);
    } else {
      theme = theme.copyWith(colorScheme: ThemeData.light().colorScheme);
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      /// Init App States
      stateGlobal.init();
      stateUser.init();
    });

    final mediaQuery = MediaQuery.of(context);

    /// Return child component
    return MediaQuery(
      // This forces the text scaler to a fixed value of 1.0
      data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
      child: Theme(
        data: theme,
        child: StreamBuilder<UserStatus>(
          key: Key('init-app-user-status-stream-builder'),
          stream: stateUser.streamStatus,
          initialData: stateUser.userStatus,
          builder: (context, snapshot) {
            bool resolved = false;
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                resolved = false;
              default:
                resolved = true;
            }
            final status = snapshot.data;
            if (status?.ready == true) {
              resolved = true;
            }

            /// Loading widget
            final loadingWidget = LoadingScreen(
              key: Key('init-app-loading-screen'),
            );
            if (!resolved) return loadingWidget;

            /// Force build for UserStatus updates
            final now = DateTime.now().millisecondsSinceEpoch;
            return Container(
              key: ValueKey('init-app-child-${status?.signedIn}-$now'),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
