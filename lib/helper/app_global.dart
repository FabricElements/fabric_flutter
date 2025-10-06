import 'package:flutter/material.dart';

class AppGlobal {
  AppGlobal._();

  /// A global key is often needed to navigate from non-widget/non-context code
  /// Is essential to have this key in order to navigate from background notifications:
  /// MaterialApp(
  ///   navigatorKey: AppGlobal.navigatorKey,
  ///   ...
  /// )
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// A global key is often needed to access the ScaffoldState
  /// Is essential to have this key in order to open the drawer from non-widget/non-context code:
  /// Scaffold(
  ///  key: AppGlobal.scaffoldKey,
  ///  ...
  ///  )
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  /// A global key is often needed to access the ScaffoldMessengerState
  /// Is essential to have this key in order to show SnackBars from non-widget/non-context code:
  /// ScaffoldMessenger(
  /// key: AppGlobal.snackbarKey,
  /// ...
  /// )
  static final GlobalKey<ScaffoldMessengerState> snackbarKey =
      GlobalKey<ScaffoldMessengerState>();
}
