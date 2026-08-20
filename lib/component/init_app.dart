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

/// Lower bound applied to the operating system text scale when a host
/// application opts in through [InitApp.honorSystemTextScale].
///
/// Fabric Flutter layouts are designed at a scale factor of `1.0`, so shrinking
/// text below that value only reduces legibility without freeing meaningful
/// space. This value is unused while text scaling stays disabled, which is the
/// default.
const double kDefaultMinTextScaleFactor = 1.0;

/// Upper bound applied to the operating system text scale when a host
/// application opts in through [InitApp.honorSystemTextScale].
///
/// The value covers the accessibility text sizes users actually enable while
/// keeping dense components (tables, chips, navigation chrome) laid out
/// correctly. Applications that verified their layouts at larger scales can
/// raise or remove the bound through [InitApp.maxTextScaleFactor]. This value is
/// unused while text scaling stays disabled, which is the default.
const double kDefaultMaxTextScaleFactor = 1.4;

/// Returns [textScaler] restricted to the range defined by [min] and [max].
///
/// Passing `null` for both bounds returns [textScaler] untouched. This helper is
/// only reached once a host application enables
/// [InitApp.honorSystemTextScale]; it never disables scaling on its own.
TextScaler clampedTextScaler(
  TextScaler textScaler, {
  double? min,
  double? max,
}) {
  if (min == null && max == null) return textScaler;
  return textScaler.clamp(
    minScaleFactor: min ?? 0.0,
    maxScaleFactor: max ?? double.infinity,
  );
}

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
  ///
  /// [honorSystemTextScale] is opt-in and defaults to `false`, which preserves
  /// the long-standing Fabric Flutter behavior of rendering text at a fixed
  /// scale. See [honorSystemTextScale] before enabling it.
  const InitApp({
    super.key,
    this.providers = const [],
    required this.child,
    this.notifications = false,
    this.honorSystemTextScale = false,
    this.minTextScaleFactor = kDefaultMinTextScaleFactor,
    this.maxTextScaleFactor = kDefaultMaxTextScaleFactor,
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

  /// Stores whether the operating system text scale is applied to the app.
  ///
  /// Defaults to `false`, which renders text with [TextScaler.noScaling].
  ///
  /// Disabling text scaling is deliberate, not an oversight: honoring the
  /// operating system text scale caused a layout bug on iOS, so Fabric Flutter
  /// pins the scale by default and every consuming application has been sized
  /// against that behavior. Please do not "fix" this by removing the opt-in —
  /// see the note in [_InitAppChildState.build].
  ///
  /// Setting this to `true` restores standard Flutter behavior: the user's
  /// preference is honored, clamped to [minTextScaleFactor] and
  /// [maxTextScaleFactor]. Enabling it is at the host application's own risk and
  /// should follow a visual pass over every screen at the largest supported
  /// scale, with particular attention to iOS.
  final bool honorSystemTextScale;

  /// Stores the lower bound applied to the operating system text scale.
  ///
  /// Only used when [honorSystemTextScale] is `true`. Defaults to
  /// [kDefaultMinTextScaleFactor] so text is never rendered smaller than the
  /// design size. Pass `null` to allow the user's smaller text sizes.
  final double? minTextScaleFactor;

  /// Stores the upper bound applied to the operating system text scale.
  ///
  /// Only used when [honorSystemTextScale] is `true`. Defaults to
  /// [kDefaultMaxTextScaleFactor], which covers larger accessibility text sizes
  /// while keeping dense layouts readable. Pass `null` to apply the user's text
  /// scale without any upper bound.
  final double? maxTextScaleFactor;

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
      child: InitAppChild(
        notifications: notifications,
        honorSystemTextScale: honorSystemTextScale,
        minTextScaleFactor: minTextScaleFactor,
        maxTextScaleFactor: maxTextScaleFactor,
        child: child,
      ),
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
    this.honorSystemTextScale = false,
    this.minTextScaleFactor = kDefaultMinTextScaleFactor,
    this.maxTextScaleFactor = kDefaultMaxTextScaleFactor,
  });

  /// Stores the application subtree shown once bootstrap work is complete.
  ///
  /// This widget is wrapped in the resolved [Theme] and a [MediaQuery] whose
  /// text scaler is fixed unless [honorSystemTextScale] is enabled.
  final Widget child;

  /// Stores whether notification lifecycle management runs for signed-in users.
  ///
  /// Keeping this value `false` skips the notification initialization and clear
  /// logic driven by [StateNotifications].
  final bool notifications;

  /// Stores whether the operating system text scale is applied to the app.
  ///
  /// Defaults to `false`, matching [InitApp.honorSystemTextScale]. See that
  /// member for why text scaling is disabled by default.
  final bool honorSystemTextScale;

  /// Stores the lower bound applied to the operating system text scale.
  ///
  /// Only used when [honorSystemTextScale] is `true`. Pass `null` to leave the
  /// lower bound untouched.
  final double? minTextScaleFactor;

  /// Stores the upper bound applied to the operating system text scale.
  ///
  /// Only used when [honorSystemTextScale] is `true`. Pass `null` to leave the
  /// upper bound untouched.
  final double? maxTextScaleFactor;

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

  /// Returns the text scaler applied to the whole application subtree.
  ///
  /// Returns [TextScaler.noScaling] unless the host application opted in via
  /// [InitAppChild.honorSystemTextScale], in which case the operating system
  /// preference is used, clamped to the configured bounds.
  TextScaler _resolveTextScaler(BuildContext context) {
    // Text scaling is DISABLED BY DELIBERATE DESIGN — this is not an oversight
    // and should not be "fixed" by deleting the branch below.
    //
    // Honoring the operating system text scale caused a layout bug on iOS, and
    // every application consuming this package has been visually sized against
    // the fixed-scale behavior. Removing this would silently resize text across
    // all of those apps.
    //
    // Applications that want the platform behavior can opt in per app with
    // InitApp(honorSystemTextScale: true), optionally tuning
    // minTextScaleFactor / maxTextScaleFactor, and should do so only after a
    // visual pass over every screen — especially on iOS.
    if (!widget.honorSystemTextScale) return TextScaler.noScaling;
    return clampedTextScaler(
      MediaQuery.textScalerOf(context),
      min: widget.minTextScaleFactor,
      max: widget.maxTextScaleFactor,
    );
  }

  /// Returns either the loading screen or the application [InitAppChild.child].
  ///
  /// The method derives a theme from the current platform brightness and delays
  /// rendering the child until the [UserStatus] stream reports a resolved state.
  /// Text is rendered at a fixed scale unless
  /// [InitAppChild.honorSystemTextScale] is enabled; see [_resolveTextScaler]
  /// for why that default exists.
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
    final textScaler = _resolveTextScaler(context);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
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
