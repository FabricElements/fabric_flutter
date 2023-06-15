import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateNotifications extends ChangeNotifier {
  StateNotifications();

  bool initialized = Firebase.apps.isNotEmpty;

  FirebaseMessaging? get _firebaseMessaging =>
      initialized ? FirebaseMessaging.instance : null;

  String? _token;
  Map<String, dynamic> _notification = {};
  dynamic _uid = '';
  bool _initialized = false;
  Function(Map<String, dynamic> message)? _callback;

  /// [token] Returns device token
  String get token => _token ?? '';

  /// Update user token on the firestore user/{uid}
  void _updateUserToken(String? tokenId) async {
    if (tokenId == null || tokenId.isEmpty || _uid.isEmpty) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('user').doc(_uid).set({
        'backup': false,
        'fcm': tokenId,
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
    Map<dynamic, dynamic> toNotify = _notification;
    _notification = {};
    return toNotify;
  }

  Future<String?> getToken() async {
    if (!initialized) throw 'Initialize Firebase app first';
    _firebaseMessaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: true,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
    String? token = await _firebaseMessaging!.getToken();
    return token;
  }

  Map<String, dynamic> _clearObject(Map<String, dynamic> data, String key) {
    if (data.isEmpty || data[key] == null) {
      return data;
    }
    Map<String, dynamic> data0 = Map<String, dynamic>.from(data);
    // Format the child map
    Map<String, dynamic> stringMap = data0[key].cast<String, dynamic>();
    data0.addAll(stringMap);
    data0.remove(key);
    return data0;
  }

  /// Return notify values
  _notify({RemoteMessage? message, String origin = 'message'}) async {
    if (message == null) return;
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;
    Map<String, dynamic> message0 = data;
    message0 = _clearObject(message0, 'fcm_options');
    message0 = _clearObject(message0, 'aps');
    message0 = _clearObject(message0, 'alert');

    message0 = _clearObject(message0, 'data');
    message0 = _clearObject(message0, 'notification');
    if (!kIsWeb) {
      /// Add OS
      message0.addAll({'os': Platform.operatingSystem});
    }

    /// Add origin
    message0.addAll({'origin': origin});

    if (notification?.title != null) {
      message0.putIfAbsent('title', () => notification?.title);
    }
    if (notification?.body != null) {
      message0.putIfAbsent('body', () => notification?.body);
    }

    /// Add valid path by default
    String path = message0['path'] ?? '';
    if (path.isNotEmpty && path.startsWith('/')) {
      message0['path'] = path;
    } else {
      message0['path'] = '';
    }

    /// Add data to stream
    _notification = message0;
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
      String? pushToken = await getToken();
      _token = pushToken;
      _updateUserToken(token);
      // Any time the token refreshes, store this in the database too.
      FirebaseMessaging.instance.onTokenRefresh.listen(_updateUserToken);
    }
    initNotifications();
  }

  /// Define user id
  set uid(dynamic id) {
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
