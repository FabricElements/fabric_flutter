import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../helper/print_color.dart';

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateNotifications extends ChangeNotifier {
  StateNotifications();

  bool initialized = Firebase.apps.isNotEmpty;

  String? _token;
  Map<String, dynamic> _notification = {};
  dynamic _uid = '';
  bool _initialized = false;
  Function(Map<String, dynamic> message)? _callback;

  /// [token] Returns device token
  String? get token => _token;

  /// Update user token on the firestore user/{uid}
  void _updateUserToken(String? tokenId) async {
    if (!initialized || _uid.isEmpty || tokenId == _token) return;
    try {
      await FirebaseFirestore.instance.collection('user').doc(_uid).set({
        'backup': false,
        'fcm': tokenId ?? FieldValue.delete(),
        'updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint(
          PrintColor.error('error saving user token: ${error.toString()}'));
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
    // You may set the permission requests to "provisional" which allows the user to choose what type
    // of notifications they would like to receive once the user receives a notification.
    final notificationSettings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      // provisional: true,
      sound: true,
    );
    switch (notificationSettings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        debugPrint(
            'User granted permission: ${notificationSettings.authorizationStatus}');
        break;
      default:
        return null;
    }
    String? token = await FirebaseMessaging.instance.getToken();
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
    if ((notification?.apple?.imageUrl ?? notification?.android?.imageUrl) !=
        null) {
      message0.putIfAbsent(
          'imageUrl',
          () =>
              notification?.apple?.imageUrl ?? notification?.android?.imageUrl);
    }

    /// Add valid path by default
    String path = message0['path'] ?? '';
    if (path.isNotEmpty && path.startsWith('/')) {
      message0['path'] = path;
    } else {
      message0['path'] = '';
    }
    message0.addAll({
      'clear': bool.tryParse(message0['clear'], caseSensitive: false) ?? false,
    });

    /// Add data to stream
    _notification = message0;
    try {
      if (_callback != null) await _callback!(_notification);
    } catch (error) {
      debugPrint(PrintColor.error('Callback Error: $error'));
    }
  }

  initNotifications() async {
    // Prevent calling this function in debug mode
    if (kIsWeb && kDebugMode) return;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _notify(message: message, origin: 'message');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await Future.delayed(const Duration(milliseconds: 200));
      await _notify(message: message, origin: 'resume');
    });
  }

  /// Initializes the notifications and starts listening
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Any time the token refreshes, store this in the database too.
    // FirebaseMessaging.instance.onTokenRefresh.listen(_updateUserToken);
    initNotifications();
  }

  /// Get user token for notifications
  /// from the main App to prevent blocking call
  Future<void> getUserToken() async {
    // Prevent calling this function in debug mode
    if (kIsWeb && kDebugMode) return;
    if (!_initialized) await init();
    if (_token == null) {
      final newToken = await getToken();
      _updateUserToken(newToken);
      _token = newToken;
      notifyListeners();
    }
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
