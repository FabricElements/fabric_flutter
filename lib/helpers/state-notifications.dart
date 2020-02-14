import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import 'push-provider.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateNotifications extends ChangeNotifier {
  StateNotifications();

  final pushProvider = new PushProvider();
  String _token;
  Map<dynamic, dynamic> _notification = {};
  String _uid = "";
  bool _initialized = false;
  Future<void> Function(Map<dynamic, dynamic> data) _callback;

  /// [token] Returns device token
  String get token => _token ?? "";

  /// Update user token on the firestore user/{uid}
  void _updateUserToken() async {
    if (token.isEmpty || _uid.isEmpty) {
      return;
    }
    try {
      await Firestore.instance.collection("user").document(_uid).setData({
        "backup": false,
        "tokens": FieldValue.arrayUnion([token]),
        "updated": FieldValue.serverTimestamp(),
      }, merge: true);
    } catch (error) {
      print("error saving user token: ${error.message}");
    }
  }

  /// [notification] returns the body oof the notification
  Map<dynamic, dynamic> get notification {
    if (_notification.isEmpty) {
      return {};
    }
    Map<dynamic, dynamic> _toNotify = _notification;
    _notification = {};
    return _toNotify;
  }

  /// Initializes the notifications and starts listening
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    if (token.isEmpty) {
      dynamic _pushToken = await pushProvider.getToken();
      _token = _pushToken;
      _updateUserToken();
    }
    pushProvider.initNotifications();
    if (token.isNotEmpty && !_initialized) {
      pushProvider.message.listen((arg) async {
        _notification = arg;
        notifyListeners();
        try {
          await _callback(arg);
        } catch (error) {
          print(error);
        }
      });
    }
    _initialized = true;
  }

  /// Define user id
  set uid(String id) {
    _uid = id ?? "";
    _updateUserToken();
  }

  /// Default function call every time the id changes.
  /// Override this function to add custom features for your state.
  void reset() {
    _token = "";
    _notification = {};
    _uid = "";
    _initialized = false;
  }

  set callback(Future<void> Function(Map<dynamic, dynamic> data) callback) {
    _callback = callback;
  }

  /// Clear document data
  void clear() {
    reset();
    notifyListeners();
  }
}
