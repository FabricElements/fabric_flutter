import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Tracks analytics integration state for the application.
///
/// Widgets generally do not rebuild often from this notifier, but keeping it as
/// a [ChangeNotifier] lets app-level listeners react when analytics is cleared
/// or reset. The state records the current screen name and exposes the current
/// [FirebaseAnalytics] instance and matching navigator [observer] when Firebase
/// is available.
class StateAnalytics extends ChangeNotifier {
  /// Creates the analytics state holder.
  StateAnalytics();

  /// Stores the last screen name sent to analytics.
  String? _screenName = '';

  /// Indicates whether Firebase has already been initialized.
  bool initialized = Firebase.apps.isNotEmpty;

  /// Returns the shared [FirebaseAnalytics] instance when Firebase is ready.
  FirebaseAnalytics? get analytics =>
      initialized ? FirebaseAnalytics.instance : null;

  /// Returns a [FirebaseAnalyticsObserver] for navigator tracking.
  FirebaseAnalyticsObserver? get observer =>
      initialized ? FirebaseAnalyticsObserver(analytics: analytics!) : null;

  /// Sends the current screen name to Firebase Analytics.
  void _sendCurrentTabToAnalytics(String screenName) {
    observer?.analytics.logScreenView(screenName: screenName);
  }

  /// Updates the active screen name and logs it to analytics.
  ///
  /// Empty values and duplicate screen names are ignored so navigation churn
  /// does not create noisy analytics events.
  set screenName(String screenName) {
    if (screenName.isEmpty || screenName == _screenName) {
      return;
    }
    _screenName = screenName;
    _sendCurrentTabToAnalytics(screenName);
  }

  /// Resets analytics-specific derived state.
  ///
  /// Override this in subclasses when clearing analytics should also wipe extra
  /// cached data.
  void reset() {}

  /// Clears the tracked screen state and notifies listeners when possible.
  void clear() {
    _screenName = null;
    reset();
    if (initialized) notifyListeners();
  }
}
