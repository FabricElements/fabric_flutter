import 'dart:async';
import 'dart:io';

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
    if (data == null || data.isEmpty || data[key] == null) {
      return data;
    }
    Map<String, dynamic> _data = Map<String, dynamic>.from(data);
    // Format the child map
    Map<String, dynamic> stringMap = _data[key].cast<String, dynamic>();
    _data.addAll(stringMap);
    _data.remove(key);
    return _data;
  }

  void _notify(Map<String, dynamic> message, String origin) async {
    try {
      Map<String, dynamic> _message = message;

      /// ios
      _message = _clearObject(_message, "fcm_options");
      _message = _clearObject(_message, "aps");
      _message = _clearObject(_message, "alert");

      /// android
      _message = _clearObject(_message, "data");
      _message = _clearObject(_message, "notification");

      /// Add OS
      _message.addAll({"os": Platform.operatingSystem});

      /// Add origin
      _message.addAll({"origin": origin});

      /// Add valid path by default
      String path = _message["path"] ?? "";
      if (path != null && path.isNotEmpty && path.startsWith("/")) {
        _message["path"] = path;
      } else {
        _message["path"] = "";
      }

      /// Add data to stream
      _messagesStreamController.sink.add(_message);
      _notification = _message;
      notifyListeners();
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