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

/// Enum to define the origin of the notification
enum NotificationOrigin { message, open, resume }

/// A global key is often needed to navigate from non-widget/non-context code
/// Is essential to have this key in order to navigate from background notifications:
/// MaterialApp(
///   navigatorKey: navigatorKey,
///   ...
/// )
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  NotificationData? formatMessage({
    RemoteMessage? message,
    required NotificationOrigin origin,
  }) {
    if (message == null) return null;
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;
    Map<String, dynamic> messageData = data;
    messageData = _clearObject(messageData, 'fcm_options');
    messageData = _clearObject(messageData, 'aps');
    messageData = _clearObject(messageData, 'alert');
    messageData = _clearObject(messageData, 'data');
    messageData = _clearObject(messageData, 'notification');

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
    messageData.addAll({'os': userOs.name});

    /// Add origin
    messageData.addAll({'origin': origin});
    if (notification?.title != null) {
      messageData.putIfAbsent('title', () => notification?.title);
    }
    if (notification?.body != null) {
      messageData.putIfAbsent('body', () => notification?.body);
    }
    if ((notification?.apple?.imageUrl ?? notification?.android?.imageUrl) !=
        null) {
      messageData.putIfAbsent(
        'imageUrl',
        () => notification?.apple?.imageUrl ?? notification?.android?.imageUrl,
      );
    }

    /// Add valid path by default
    String? path = (messageData['path'] as String?)?.trim();
    if (path != null && path.isNotEmpty && path.startsWith('/')) {
      messageData['path'] = path;
      messageData['duration'] ??= 10.0;
    } else {
      messageData['path'] = null;
    }

    /// Add duration
    messageData.putIfAbsent('duration', () => 5);

    /// Add clear
    messageData.addAll({
      'clear':
          bool.tryParse(
            messageData['clear']?.toString() ?? 'false',
            caseSensitive: false,
          ) ??
          false,
    });

    /// Add account
    String? account = (messageData['account'] as String?)?.trim();
    if (account != null && account.isNotEmpty) {
      messageData['account'] = account;
    } else {
      messageData['account'] = null;
    }

    /// Add data to stream
    _notification = NotificationData.fromJson(messageData);
    return _notification;
  }

  /// Initialize the notifications
  Future<void> initNotifications() async {
    // Prevent calling this function in debug mode
    if (kDebugMode) return;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final formatted = formatMessage(
        message: message,
        origin: NotificationOrigin.message,
      );
      try {
        if (_callback != null) await _callback!(formatted!);
      } catch (error) {
        debugPrint(LogColor.error('Callback Error: $error'));
      }
    });

    /// When the app is opened from a terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await Future.delayed(const Duration(milliseconds: 1500));
      final formatted = formatMessage(
        message: message,
        origin: NotificationOrigin.resume,
      );
      if (formatted != null && formatted.path != null) {
        _navigateToView(
          path: formatted.path!,
          args: {'account': formatted.account, 'id': formatted.id},
        );
      }
    });

    /// When the app is opened from a background state
    FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
      await Future.delayed(const Duration(milliseconds: 1500));
      final formatted = formatMessage(
        message: message,
        origin: NotificationOrigin.open,
      );
      if (formatted != null && formatted.path != null) {
        _navigateToView(
          path: formatted.path!,
          args: {'account': formatted.account, 'id': formatted.id},
        );
      }
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

  /// Navigate to a specific view based on the path and arguments
  /// Example path: /product?id=123&account=abc
  void _navigateToView({
    required String path,
    required Map<String, dynamic> args,
  }) {
    // 1. Parse the path and extract necessary arguments (e.g., from a URL-like format)
    final uri = Uri.parse(path);
    final route = uri.path; // e.g., /product
    final String? id = uri.queryParameters['id'];
    final String? account = uri.queryParameters['account'];
    Map<String, dynamic> argsFinal = {};

    if (id != null && id.isNotEmpty) {
      argsFinal['id'] = id;
    }
    if (account != null && account.isNotEmpty) {
      argsFinal['account'] = account;
    }

    /// Merge with provided args
    argsFinal = {...argsFinal, ...args};
    if (route.isNotEmpty && route.startsWith('/')) {
      navigatorKey.currentState?.pushNamed(route, arguments: argsFinal);
    } else {
      // Default or home
      navigatorKey.currentState?.pushNamed('/', arguments: argsFinal);
    }
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
