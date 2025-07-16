import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../helper/log_color.dart';
import '../serialized/notification_data.dart';
import '../serialized/user_data.dart';

enum NotificationOrigin { message, open, resume }

/// This is a change notifier class which keeps track of state within the campaign builder views.
class StateNotifications extends ChangeNotifier {
  StateNotifications();

  bool initialized = Firebase.apps.isNotEmpty;

  String? token;
  NotificationData? _notification;
  dynamic _uid = '';
  bool _initialized = false;
  Function(NotificationData message)? _callback;

  /// Update user token on the firestore user/{uid}
  void _updateUserToken(String? tokenId) async {
    if (!initialized || _uid.isEmpty || tokenId == token) return;
    try {
      await FirebaseFirestore.instance.collection('user').doc(_uid).set({
        'backup': false,
        'fcm': tokenId ?? FieldValue.delete(),
        'updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint(
        LogColor.error('error saving user token: ${error.toString()}'),
      );
    }
    token = tokenId;
    notifyListeners();
  }

  /// [notification] returns the body oof the notification
  NotificationData? get notification => _notification;

  /// Get the user messaging token
  Future<String?> getToken() async {
    if (!initialized) throw 'Initialize Firebase app first';
    // You may set the permission requests to "provisional" which allows the user to choose what type
    // of notifications they would like to receive once the user receives a notification.
    final notificationSettings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          announcement: true,
          badge: true,
          carPlay: true,
          criticalAlert: true,
          provisional: true,
          sound: true,
          providesAppNotificationSettings: true,
        );
    switch (notificationSettings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        debugPrint(
          'User granted permission: ${notificationSettings.authorizationStatus}',
        );
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
  Future<void> _notify({RemoteMessage? message, required NotificationOrigin origin}) async {
    if (message == null) return;
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;
    Map<String, dynamic> message0 = data;
    message0 = _clearObject(message0, 'fcm_options');
    message0 = _clearObject(message0, 'aps');
    message0 = _clearObject(message0, 'alert');
    message0 = _clearObject(message0, 'data');
    message0 = _clearObject(message0, 'notification');

    /// Get user device
    UserOS userOs = UserOS.unknown;
    try {
      if (kIsWeb) {
        userOs = UserOS.web;
      } else {
        String os = Platform.operatingSystem;
        userOs = UserOS.values.firstWhere(
          (e) => e.name == os.toLowerCase(),
          orElse: () => UserOS.unknown,
        );
      }
    } catch (e) {
      debugPrint(LogColor.error('Device type error: ${e.toString()}'));
    }
    message0.addAll({'os': userOs.name});

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
        () => notification?.apple?.imageUrl ?? notification?.android?.imageUrl,
      );
    }

    /// Add valid path by default
    String? path = (message0['path'] as String?)?.trim();
    if (path != null && path.isNotEmpty && path.startsWith('/')) {
      message0['path'] = path;
      message0['duration'] ??= 10.0;
    } else {
      message0['path'] = null;
    }

    /// Add duration
    message0.putIfAbsent('duration', () => 5);

    /// Add clear
    message0.addAll({
      'clear':
          bool.tryParse(
            message0['clear']?.toString() ?? 'false',
            caseSensitive: false,
          ) ??
          false,
    });

    /// Add data to stream
    _notification = NotificationData.fromJson(message0);
    try {
      if (_callback != null) await _callback!(_notification!);
    } catch (error) {
      debugPrint(LogColor.error('Callback Error: $error'));
    }
  }

  /// Initialize the notifications
  Future<void> initNotifications() async {
    // Prevent calling this function in debug mode
    if (kDebugMode) return;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _notify(message: message, origin: NotificationOrigin.message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await Future.delayed(const Duration(milliseconds: 200));
      await _notify(message: message, origin: NotificationOrigin.resume);
    });
    FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
      await Future.delayed(const Duration(milliseconds: 500));
      await _notify(message: message, origin: NotificationOrigin.open);
    });
  }

  /// Initializes the notifications and starts listening
  Future<void> init() async {
    // Prevent calling this function in debug mode
    if (kDebugMode) return;
    // Prevent calling this function if not initialized
    if (_initialized) return;
    _initialized = true;
    // Wait for the app assign the callback
    if (_callback == null) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    // Any time the token refreshes, store this in the database too.
    // FirebaseMessaging.instance.onTokenRefresh.listen(_updateUserToken);
    initNotifications();
  }

  /// Get user token for notifications
  /// from the main App to prevent blocking call
  Future<void> getUserToken() async {
    // Prevent calling this function in debug mode
    if (kDebugMode) return;
    if (!_initialized) await init();
    final newToken = await getToken();
    _updateUserToken(newToken);
  }

  /// Define user id
  set uid(dynamic id) {
    _uid = id ?? '';
  }

  /// Default function call every time the id changes.
  /// Override this function to add custom features for your state.
  void reset() {
    token = '';
    _notification = null;
    _uid = '';
    _initialized = false;
  }

  set callback(Function(NotificationData message) callback) {
    _callback ??= callback;
  }

  /// Clear document data
  void clear() {
    reset();
  }
}
