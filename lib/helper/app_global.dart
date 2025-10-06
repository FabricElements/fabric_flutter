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
}
