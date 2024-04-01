import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateAnalytics extends ChangeNotifier {
  StateAnalytics();

  String? _screenName = '';

  bool initialized = Firebase.apps.isNotEmpty;

  /// Analytics
  FirebaseAnalytics? get analytics =>
      initialized ? FirebaseAnalytics.instance : null;

  FirebaseAnalyticsObserver? get observer =>
      initialized ? FirebaseAnalyticsObserver(analytics: analytics!) : null;

  void _sendCurrentTabToAnalytics(String screenName) {
    observer?.analytics.logScreenView(
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
    if (initialized) notifyListeners();
  }
}
