import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateNotifications extends ChangeNotifier {
  StateNotifications();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  String? _token;
  Map<String, dynamic> _notification = {};
  String _uid = '';
  bool _initialized = false;
  Function(Map<String, dynamic> message)? _callback;

  /// [token] Returns device token
  String get token => _token ?? '';

  /// Update user token on the firestore user/{uid}
  void _updateUserToken(String? _token) async {
    if (_token == null || _token.isEmpty || _uid.isEmpty) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('user').doc(_uid).set({
        'backup': false,
        'fcm': _token,
        'updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) print('error saving user token: ${error.toString()}');
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

  Future<String?> getToken() async {
    _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: true,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
    String? token = await _firebaseMessaging.getToken();
    return token;
  }

  Map<String, dynamic> _clearObject(Map<String, dynamic> data, String key) {
    if (data.isEmpty || data[key] == null) {
      return data;
    }
    Map<String, dynamic> _data = Map<String, dynamic>.from(data);
    // Format the child map
    Map<String, dynamic> stringMap = _data[key].cast<String, dynamic>();
    _data.addAll(stringMap);
    _data.remove(key);
    return _data;
  }

  /// Return notify values
  _notify({RemoteMessage? message, String origin = 'message'}) async {
    if (message == null) return;
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;
    Map<String, dynamic> _message = data;
    _message = _clearObject(_message, 'fcm_options');
    _message = _clearObject(_message, 'aps');
    _message = _clearObject(_message, 'alert');

    _message = _clearObject(_message, 'data');
    _message = _clearObject(_message, 'notification');
    if (!kIsWeb) {
      /// Add OS
      _message.addAll({'os': Platform.operatingSystem});
    }

    /// Add origin
    _message.addAll({'origin': origin});

    if (notification?.title != null) {
      _message.putIfAbsent('title', () => notification?.title);
    }
    if (notification?.body != null) {
      _message.putIfAbsent('body', () => notification?.body);
    }

    /// Add valid path by default
    String path = _message['path'] ?? '';
    if (path.isNotEmpty && path.startsWith('/')) {
      _message['path'] = path;
    } else {
      _message['path'] = '';
    }

    /// Add data to stream
    _notification = _message;
    try {
      if (_callback != null) await _callback!(_notification);
    } catch (error) {
      if (kDebugMode) print('Callback Error: $error');
    }
  }

  initNotifications() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _notify(message: message, origin: 'message');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _notify(message: message, origin: 'resume');
    });
    if (token.isNotEmpty && !_initialized) {
      // message.listen((arg) async {});
    }
    _initialized = true;
  }

  /// Initializes the notifications and starts listening
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    if (token.isEmpty) {
      String? _pushToken = await getToken();
      _token = _pushToken;
      _updateUserToken(token);
      // Any time the token refreshes, store this in the database too.
      FirebaseMessaging.instance.onTokenRefresh.listen(_updateUserToken);
    }
    initNotifications();
  }

  /// Define user id
  set uid(String? id) {
    _uid = id ?? '';
  }

  /// Default function call every time the id changes.
  /// Override this function to add custom features for your state.
  void reset() {
    _token = '';
    _notification = {};
    _uid = '';
    _initialized = false;
  }

  set callback(Function(Map<String, dynamic> message) callback) {
    _callback ??= callback;
  }

  /// Clear document data
  void clear() {
    reset();
  }
}
