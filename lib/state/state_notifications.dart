import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../helper/app_global.dart';
import '../helper/log_color.dart';
import '../serialized/notification_data.dart';
import '../serialized/user_data.dart';

/// Identifies how a push notification reached the application.
enum NotificationOrigin {
  /// The app received the notification while already in the foreground.
  message,

  /// The user opened the app from a notification tap or cold-start launch.
  open,

  /// The app resumed from the background while handling the notification.
  resume,
}

/// Coordinates Firebase Cloud Messaging state for the application.
///
/// This notifier owns device-token registration, notification payload
/// normalization, app-open handling, and optional navigation/callback behavior.
/// Applications typically initialize it once after Firebase setup, assign a
/// [callback] if custom UI work is needed, and then listen for updates via
/// [notifyListeners] or by reading [notification].
///
/// Updates propagate when the stored FCM token changes or when formatted
/// notifications are prepared. Background handling intentionally waits for
/// navigation infrastructure to be ready before attempting route changes.
class StateNotifications extends ChangeNotifier {
  /// Creates the notifications state holder.
  StateNotifications();

  /// Indicates whether Firebase is already initialized and messaging can be
  /// used safely.
  bool initialized = Firebase.apps.isNotEmpty;

  /// Stores the last device token successfully synchronized with Firestore.
  String? token;

  /// Stores the latest normalized notification payload.
  NotificationData? _notification;

  /// Stores the current user identifier whose document should receive token
  /// updates.
  dynamic _uid;

  /// Prevents notification listeners from being registered more than once.
  bool _initialized = false;

  /// Stores an optional callback used for foreground or fallback handling.
  Function(NotificationData message)? _callback;

  /// Persists the user's device token to `user/{uid}` in Firestore.
  ///
  /// Duplicate tokens are ignored so token refresh streams do not perform
  /// redundant writes. The user document stores the token in the `fcm` array so
  /// multi-device messaging can coexist cleanly.
  void _updateUserToken(String? tokenId) async {
    if (!initialized ||
        _uid == null ||
        _uid.toString().isEmpty ||
        tokenId == token) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('user').doc(_uid).set({
        'backup': false,
        'fcm': FieldValue.arrayUnion([tokenId]),
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

  /// Returns the latest normalized notification payload.
  NotificationData? get notification => _notification;

  /// Requests notification permissions and returns the current FCM token.
  ///
  /// Returns `null` when the user declines permission or when Apple push token
  /// setup fails. Callers typically invoke this from the main app flow so the
  /// permission prompt does not block unrelated state initialization.
  Future<String?> getToken() async {
    if (!initialized) throw 'Initialize Firebase app first';
    // You may set the permission requests to "provisional" which allows the user to choose what type
    // of notifications they would like to receive once the user receives a notification.
    final notificationSettings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      // criticalAlert: true, // DO NOT ENABLE THIS UNLESS YOU UNDERSTAND THE IMPLICATIONS. Custom entitlements are required
      provisional: true,
      sound: true,
      providesAppNotificationSettings: true,
    );
    debugPrint(
      'User granted permission: ${notificationSettings.authorizationStatus}',
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
    try {
      // For apple platforms, make sure the APNS token is available before making any FCM plugin API calls
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        // APNS token is available, make FCM plugin API requests...
        debugPrint(LogColor.success('APNS token: $apnsToken'));
      }
    } catch (error) {
      debugPrint(
        LogColor.error('Error getting APNS token: ${error.toString()}'),
      );
      return null;
    }

    String? token = await FirebaseMessaging.instance.getToken();
    return token;
  }

  /// Flattens nested maps stored under [key] into the top-level payload.
  ///
  /// FCM payloads can arrive with platform-specific wrappers such as `aps` or
  /// `notification`. Flattening them once keeps later parsing logic simple and
  /// ensures [NotificationData.fromJson] sees a consistent shape.
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

  /// Normalizes an FCM [message] into a [NotificationData] object.
  ///
  /// The method merges platform-specific payload wrappers, annotates the user
  /// operating system and notification [origin], fills missing title, body, and
  /// image fields when possible, sanitizes route paths, and coerces booleans and
  /// durations into predictable values.
  NotificationData? formatMessage({
    RemoteMessage? message,
    required String origin,
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

  /// Registers foreground, background, and app-open notification handlers.
  ///
  /// Call this after Firebase Messaging is available. The handlers either route
  /// the message to [callback] or attempt navigation based on the normalized
  /// payload.
  Future<void> initNotifications() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final formatted = formatMessage(
        message: message,
        origin: NotificationOrigin.message.name,
      );
      if (_callback != null && formatted != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          await _callback!(formatted);
        } catch (error) {
          debugPrint(LogColor.error('Callback Error: $error'));
        }
      }
    });

    /// When the app is opened from a terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _handleBackgroundMessage(
        message: message,
        origin: NotificationOrigin.open,
      );
    });

    /// When the app is opened from a background state
    FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
      await _handleBackgroundMessage(
        message: message,
        origin: NotificationOrigin.resume,
      );
    });

    /// Check if the app was opened from a terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _handleBackgroundMessage(
        message: initialMessage,
        origin: NotificationOrigin.open,
      );
    }
  }

  /// Handles notifications that resume or launch the app.
  ///
  /// The entry-point pragma keeps the method reachable for background isolates.
  /// The handler ensures Firebase is initialized, waits for navigation to become
  /// available, and then prefers route navigation before falling back to the
  /// registered [callback].
  @pragma('vm:entry-point')
  Future<void> _handleBackgroundMessage({
    required RemoteMessage message,
    required NotificationOrigin origin,
  }) async {
    // Try to initialize Firebase
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (error) {
        debugPrint(LogColor.error('Firebase initialization error: $error'));
        return;
      }
    }
    // Wait for the navigatorKey to be ready
    await Future.delayed(const Duration(seconds: 1));
    final formatted = formatMessage(
      message: message,
      origin: NotificationOrigin.resume.name,
    );
    // Verify navigatorKey is ready. If not, run the callback
    if (AppGlobal.navigatorKey.currentState == null) {
      await Future.delayed(const Duration(seconds: 1));
    }
    if (formatted != null) {
      try {
        await _navigateToView(
          path: formatted.path,
          args: {
            'account': formatted.account,
            'id': formatted.id,
            'origin': origin.name,
          },
        );
      } catch (error) {
        debugPrint(LogColor.error('Notification Navigation Error: $error'));
        if (_callback != null) {
          await Future.delayed(const Duration(seconds: 1));
          try {
            await _callback!(formatted);
          } catch (error) {
            debugPrint(LogColor.error('Notification Callback Error: $error'));
          }
        }
      }
    }
  }

  /// Initializes notification handling exactly once.
  ///
  /// The delayed startup gives the rest of the app time to finish wiring the
  /// optional [callback] and navigator dependencies before FCM events arrive.
  Future<void> init() async {
    // Prevent calling this function if not initialized
    if (_initialized) return;
    _initialized = true;
    await Future.delayed(const Duration(seconds: 5));
    // Wait for the app assign the callback
    if (_callback == null) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    // Any time the token refreshes, store this in the database too.
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateUserToken);
    initNotifications();
  }

  /// Fetches the current user token and synchronizes it to Firestore.
  ///
  /// The method ensures initialization has happened first so token refresh
  /// listeners and callbacks are already in place.
  Future<void> getUserToken() async {
    if (!_initialized || _uid == null) await init();
    final newToken = await getToken();
    _updateUserToken(newToken);
  }

  /// Sets the user identifier used for token persistence.
  set uid(dynamic id) {
    _uid = id;
  }

  /// Navigates to the route described by [path] and [args].
  ///
  /// Example path: /product?id=123&account=abc
  ///
  /// Invalid or empty paths are ignored. Only non-empty primitive arguments are
  /// forwarded so routes do not receive noisy placeholder values.
  Future<void> _navigateToView({
    required String? path,
    required Map<String, dynamic> args,
  }) async {
    if (path == null || path.isEmpty || !path.startsWith('/')) return;
    final currentState = AppGlobal.navigatorKey.currentState;
    if (currentState == null) {
      throw 'Navigator state is not ready';
    }
    // Remove empty, null, or whitespace-only args
    final queryParams = <String, dynamic>{};
    args.forEach((key, value) {
      if (value != null &&
          ((value is String && value.trim().isNotEmpty) ||
              (value is num) ||
              (value is bool))) {
        queryParams[key] = value;
      }
    });
    // Merge queryParams and args, with args taking precedence
    await currentState.popAndPushNamed(path, arguments: queryParams);
    // Check if the navigation was successful
    if (currentState.canPop() || currentState.widget.initialRoute == path) {
      // Successfully navigated
    } else {
      throw 'Navigation to $path failed';
    }
  }

  /// Resets all notification-related state.
  ///
  /// Override this in subclasses if extra caches or subscriptions must be
  /// cleared alongside the built-in token and payload fields.
  void reset() {
    token = null;
    _notification = null;
    _uid = null;
    _initialized = false;
  }

  /// Registers the callback used for foreground and fallback notification work.
  ///
  /// Only the first assignment wins so startup code can safely set the callback
  /// once without later rebuilds replacing it unexpectedly.
  set callback(Function(NotificationData message) callback) {
    _callback ??= callback;
  }

  /// Clears all stored notification state.
  void clear() {
    reset();
  }
}
