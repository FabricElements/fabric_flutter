import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateNotifications extends ChangeNotifier {
  StateNotifications();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  // ignore: close_sinks
  final _messagesStreamController =
      StreamController<Map<dynamic, dynamic>>.broadcast();

  Stream<Map<dynamic, dynamic>> get message => _messagesStreamController.stream;

  String _token;
  Map<dynamic, dynamic> _notification = {};
  String _uid = "";
  bool _initialized = false;
  Future<void> Function(Map<dynamic, dynamic> message) _callback;

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

  getToken() async {
    _firebaseMessaging.requestNotificationPermissions();
    String token = await _firebaseMessaging.getToken();
    return token;
  }

  Map<String, dynamic> _clearObject(Map<String, dynamic> data, String key) {
    if (data == null || data.isEmpty || !data.containsKey(key)) {
      return data;
    }
    Map<String, dynamic> _data = data;
    _data.addAll(data[key]);
    _data.remove(key);
    return data[key];
  }

  void _notify(Map<String, dynamic> message, String origin) async {
    Map<String, dynamic> _message = message;
    _message.addAll({
      "origin": origin,
    });

    /// ios
    message = _clearObject(message, "fcm_options");
    message = _clearObject(message, "aps");
    message = _clearObject(message, "alert");

    /// android
    message = _clearObject(message, "data");
    message = _clearObject(message, "notification");

    _messagesStreamController.sink.add(_message);
    _notification = _message;
    notifyListeners();
    try {
      await _callback(_notification);
    } catch (error) {
      print(error);
    }
  }

  initNotifications() async {
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async =>
          _notify(message, "message"),
      onLaunch: (Map<String, dynamic> message) async =>
          _notify(message, "launch"),
      onResume: (Map<String, dynamic> message) async =>
          _notify(message, "resume"),
    );
    if (token.isNotEmpty && !_initialized) {
      message.listen((arg) async {});
    }
    _initialized = true;
  }

  /// Initializes the notifications and starts listening
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    if (token.isEmpty) {
      dynamic _pushToken = await getToken();
      _token = _pushToken;
      _updateUserToken();
    }
    initNotifications();
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

  set callback(Future<void> Function(Map<dynamic, dynamic> message) callback) {
    _callback = callback;
  }

  /// Clear document data
  void clear() {
    reset();
    notifyListeners();
  }
}
