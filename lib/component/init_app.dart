import 'dart:async';

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
  ///
  /// The [providers] list is prepended to the built-in provider list so host
  /// applications can register their own dependencies before Fabric Flutter
  /// widgets resolve them. The [child] subtree receives every provider created
  /// by this widget, and [notifications] enables notification setup in
  /// [InitAppChild].
  const InitApp({
    super.key,
    this.providers = const [],
    required this.child,
    this.notifications = false,
  });

  /// Stores additional providers inserted ahead of the default Fabric providers.
  ///
  /// Supplying custom [SingleChildWidget] entries here lets applications extend
  /// the shared provider tree without replacing Fabric Flutter defaults.
  final List<SingleChildWidget> providers;

  /// Stores the application subtree that receives the initialized providers.
  ///
  /// Descendant widgets can read the provider values installed by [InitApp]
  /// once this subtree is built.
  final Widget child;

  /// Stores whether notification setup runs after user authentication resolves.
  ///
  /// Keeping this value `false` disables the notification lifecycle managed by
  /// [InitAppChild].
  final bool notifications;

  /// Builds the provider tree and delegates post-bootstrap work to [InitAppChild].
  ///
  /// The returned [MultiProvider] installs the standard Fabric Flutter state
  /// objects after any custom [providers], then renders [child] through
  /// [InitAppChild] so initialization work can safely read from [BuildContext].
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
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
class InitAppChild extends StatefulWidget {
  /// Creates the post-provider bootstrap widget.
  ///
  /// The [child] subtree is revealed after startup state has resolved, while
  /// [notifications] determines whether signed-in users trigger notification
  /// initialization.
  const InitAppChild({
    super.key,
    required this.child,
    this.notifications = false,
  });

  /// Stores the application subtree shown once bootstrap work is complete.
  ///
  /// This widget is wrapped in the resolved [Theme] and a fixed [MediaQuery]
  /// text scaler before it is displayed.
  final Widget child;

  /// Stores whether notification lifecycle management runs for signed-in users.
  ///
  /// Keeping this value `false` skips the notification initialization and clear
  /// logic driven by [StateNotifications].
  final bool notifications;

  @override
  State<InitAppChild> createState() => _InitAppChildState();
}

/// Owns the bootstrap subscriptions created for an [InitAppChild].
///
/// Startup work is performed once in [initState] rather than in `build` so the
/// [UserStatus] listener is registered a single time and is cancelled when the
/// widget is removed from the tree.
class _InitAppChildState extends State<InitAppChild> {
  /// Tracks the [StateUser.streamStatus] subscription so it can be cancelled.
  ///
  /// Registering this in [initState] instead of `build` prevents a new listener
  /// from being added on every rebuild, which previously caused analytics and
  /// notification setup to run once per accumulated subscription.
  StreamSubscription<UserStatus>? _statusSubscription;

  /// Registers the one-time bootstrap listeners for the app.
  ///
  /// Provider lookups use `listen: false` because this runs outside of `build`
  /// and must not create a dependency on the located state objects.
  @override
  void initState() {
    super.initState();
    final stateGlobal = Provider.of<StateGlobal>(context, listen: false);
    final stateUser = Provider.of<StateUser>(context, listen: false);
    final stateNotifications = Provider.of<StateNotifications>(
      context,
      listen: false,
    );
    final stateAnalytics = Provider.of<StateAnalytics>(context, listen: false);

    stateUser.onError = (String? e) => (e != null)
        ? debugPrint(LogColor.error('StateUser.onError: $e'))
        : null;

    _statusSubscription = stateUser.streamStatus.listen((status) async {
      if (status.signedIn) {
        try {
          stateAnalytics.analytics?.setUserId(id: status.uid);
        } catch (error) {
          debugPrint(LogColor.error('FirebaseAnalytics error: $error'));
        }
      }

      if (widget.notifications) {
        try {
          if (status.signedIn) {
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
              stateNotifications.clear();
            }
          }
        } catch (error) {
          debugPrint(LogColor.error('InitAppChild error: $error'));
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      stateGlobal.init();
      stateUser.init();
    });
  }

  /// Cancels the bootstrap subscription when the widget leaves the tree.
  @override
  void dispose() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
    super.dispose();
  }

  /// Returns either the loading screen or the application [InitAppChild.child].
  ///
  /// The method derives a theme from the current platform brightness and delays
  /// rendering the child until the [UserStatus] stream reports a resolved state.
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    final brightness = MediaQuery.platformBrightnessOf(context);
    if (brightness == Brightness.dark) {
      theme = theme.copyWith(colorScheme: ThemeData.dark().colorScheme);
    } else {
      theme = theme.copyWith(colorScheme: ThemeData.light().colorScheme);
    }

    final stateUser = Provider.of<StateUser>(context, listen: false);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
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

            if (!resolved) {
              return const LoadingScreen(key: Key('init-app-loading-screen'));
            }

            // The key intentionally depends only on the signed-in flag. It used
            // to include `DateTime.now()`, which produced a new key on every
            // rebuild and forced Flutter to discard and recreate the entire
            // application subtree each time.
            return KeyedSubtree(
              key: ValueKey('init-app-child-${status?.signedIn}'),
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
