import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateAnalytics extends ChangeNotifier {
  StateAnalytics();

  String? _screenName = '';

  /// Analytics
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  void _sendCurrentTabToAnalytics(String screenName) {
    observer.analytics.setCurrentScreen(
      screenName: screenName,
    );
  }

  /// Set [screenName]
  set screenName(String screenName) {
    if (screenName.isEmpty || screenName == _screenName) {
      return;
    }
    _screenName = screenName;
    _sendCurrentTabToAnalytics(screenName);
  }

  /// Default function call every time the id changes.
  /// Override this function to add custom features for your state.
  void reset() {}

  /// Clear document data
  void clear() {
    _screenName = null;
    reset();
    notifyListeners();
  }
}
