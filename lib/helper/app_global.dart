import 'package:flutter/material.dart';

/// Stores application-wide keys needed outside the widget tree.
///
/// These keys let services, callbacks, and background handlers interact with
/// navigation and scaffold state when a local [BuildContext] is unavailable.
class AppGlobal {
  /// Prevents this utility class from being instantiated.
  AppGlobal._();

  /// Provides access to the root [NavigatorState] from non-widget code.
  ///
  /// Assign this key to `MaterialApp.navigatorKey` so background notifications,
  /// services, or other helpers can trigger navigation without a context.
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Provides access to the root [ScaffoldState] from non-widget code.
  ///
  /// Assign this key to a top-level [Scaffold] when helpers need to open a
  /// drawer or inspect scaffold state without receiving a [BuildContext].
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Provides access to the root [ScaffoldMessengerState].
  ///
  /// Assign this key to `MaterialApp.scaffoldMessengerKey` so services can show
  /// snack bars and related transient UI outside the widget hierarchy.
  static final GlobalKey<ScaffoldMessengerState> snackbarKey =
      GlobalKey<ScaffoldMessengerState>();
}
