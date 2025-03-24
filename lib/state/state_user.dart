import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fabric_flutter/variables.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helper/log_color.dart';
import '../helper/user_roles.dart';
import '../helper/utils.dart';
import '../serialized/user_data.dart';
import '../serialized/user_status.dart';
import 'state_document.dart';

final _auth = FirebaseAuth.instance;
final db = FirebaseFirestore.instance;

/// This is a change notifier class which keeps track of state within the widgets.
class StateUser extends StateDocument {
  StateUser();

  /// State specific functionality
  User? _userObject;
  Map<String, dynamic>? _claims;
  String? _pingReference;
  DateTime _pingLast = DateTime.now().subtract(const Duration(minutes: 10));

  bool _init = false;
  String? _language;
  ThemeMode? _theme;

  // Initialize the user status
  bool _ready = false;

  @override
  int get debounceTime =>
      _ready && !loading && initialized ? super.debounceTime : 3000;

  // Internet connection status
  bool connected = true;
  bool connectionChanged = false;
  String? connectedTo;

  /// More at [streamStatus]
  /// ignore: close_sinks
  final _controllerStreamStatus = StreamController<UserStatus>.broadcast();

  /// More at [streamUser]
  /// ignore: close_sinks
  final _controllerStreamUser = StreamController<User?>.broadcast();

  /// More at [streamSerialized]
  /// ignore: close_sinks
  final _controllerStreamSerialized = StreamController<UserData?>.broadcast();

  /// Independent function to clear all credential data
  void clearAuth({bool notify = false}) {
    clear(notify: false);
    _theme = null;
    _userObject = null;
    _claims = null;
    _token = null;
    error = null;
    if (notify) notifyListeners();
  }

  /// More at [token]
  String? _token;

  /// Gets the authenticated user token and retrieves costume claims
  _getToken(User? userObject) async {
    _claims = null;
    _token = null;
    if (userObject != null) {
      try {
        final tokenResult = await userObject.getIdTokenResult();
        _token = tokenResult.token;
        _claims = tokenResult.claims;
      } catch (e) {
        debugPrint(LogColor.error(e));
      }
    }
    if (userObject != null && initialized) notifyListeners();
    await _userStatusUpdate();
  }

  /// Get user token
  String? get token {
    if (_token == null) _getToken(object);
    return _token;
  }

  /// Get user id
  String? get id => _userObject?.uid;

  /// Set object with the [User] data
  set object(User? user) {
    _userObject = user;
    _controllerStreamUser.sink.add(_userObject);
    if (initialized) notifyListeners();
  }

  /// [admin] Returns true if the authenticated user is an admin
  bool get admin => role == 'admin';

  /// [role] Returns user role
  String get role => claims['role'] ?? serialized.role;

  /// [object] Returns a [User] object
  User? get object => _userObject;

  Map<String, dynamic> get claims => _claims ?? {};

  /// Returns serialized data [UserData]
  @override
  UserData get serialized {
    UserData userDataSerialized = UserData.fromJson(data ?? {});
    return userDataSerialized;
  }

  /// [signedIn] Returns true when the user is authenticated
  bool get signedIn => _userObject != null;

  /// Returns the current user role
  String roleFromData({
    String? group,

    /// [clean] returns the role without the group
    bool clean = false,
  }) {
    if (id != null && admin) {
      return role;
    }
    if (group == null || data == null) {
      return role;
    }
    return UserRoles.roleFromData(
      group: group,
      compareData: data,
      role: role,
      clean: clean,
    );
  }

  /// Ping user
  void ping(String reference) async {
    if (kIsTest || ref == null || reference == _pingReference) return;
    _pingLast = serialized.ping ?? _pingLast;
    DateTime timeRef = DateTime.now().subtract(const Duration(minutes: 1));
    if (_pingLast.isAfter(timeRef)) return;
    _pingReference = reference;
    _pingLast = DateTime.now(); // Define before saving because it's async
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

    /// Save ping data
    try {
      await ref?.set(
        {
          'ping': FieldValue.serverTimestamp(),
          'os': userOs.name,
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint(LogColor.error('User ping error: ${error.toString()}'));
    }
  }

  /// Sign Out user
  void signOut() async {
    await cancel();
    try {
      /// Ping user before sign out to change the status
      await ref?.set(
        {
          'ping': DateTime.timestamp().subtract(const Duration(minutes: 5)),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint(LogColor.error('User ping error: ${error.toString()}'));
    }
    clearAuth(notify: false);
    await _auth.signOut();
    notifyListeners();
  }

  /// Displays content only if the the role matches for current user
  bool accessByRole({
    String? group,
    List<String> roles = const ['admin'],
  }) {
    return roles.contains(roleFromData(group: group));
  }

  UserStatus? _lastUserStatus;

  /// User Status
  UserStatus get userStatus => UserStatus(
        role: role,
        admin: admin,
        signedIn: signedIn,
        uid: object?.uid,
        language: language,
        theme: theme,
        connected: connected,
        connectionChanged: connectionChanged,
        connectedTo: connected ? connectedTo : null,
        ready: _ready &&
            _init &&
            !loading &&
            ((!initialized && data == null) ||
                (initialized && (data?.isNotEmpty ?? false))),
      );

  /// Update user status data
  _userStatusUpdate() async {
    if (!_ready || !userStatus.ready) return;
    // Basic comparison
    if (_lastUserStatus == userStatus) return;
    Map<String, dynamic> oldUserStatus = _lastUserStatus?.toJson() ?? {};
    Map<String, dynamic> newUserStatus = userStatus.toJson();
    if (const DeepCollectionEquality().equals(oldUserStatus, newUserStatus)) {
      return;
    }
    _lastUserStatus = userStatus;
    _controllerStreamStatus.sink.add(userStatus);
    notifyListeners();
  }

  /// Refresh auth state
  _refreshAuth(User? userObject) async {
    if (!_init) return;
    _ready = false;
    if (userObject == null) {
      await cancel(clear: true);
      clearAuth(notify: true);
      _ready = true;
      await _userStatusUpdate();
      return;
    }
    try {
      /// Get User document data
      ref = db.collection('user').doc(userObject.uid);
      await listen();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint(LogColor.error(
          'StateUser - Listen User Document error: ${e.toString()}'));
    }
    try {
      /// Get user token
      // Call before _controllerStreamStatus to prevent unauthenticated calls
      await _getToken(userObject);
    } catch (e) {
      debugPrint(
          LogColor.error('StateUser - Refresh auth error: ${e.toString()}'));
    }
    object = userObject;
    _ready = true;
    await _userStatusUpdate();
  }

  /// Init app and prevent duplicated calls
  void init() {
    if (_init) return;
    _init = true;
    Utils.getLanguage()
        .then((value) => _language = value)
        .catchError((error) => '');

    /// Listen to user changes
    _auth
        .userChanges()
        .listen(_refreshAuth, onError: (e) => error = e.toString());

    /// Check connectivity
    try {
      Connectivity().onConnectivityChanged.listen(
            (results) async {
              if (results.firstOrNull?.name != connectedTo) {
                ConnectivityResult connectivityStatus = ConnectivityResult.none;
                if (results.contains(ConnectivityResult.wifi)) {
                  connectivityStatus = ConnectivityResult.wifi;
                } else if (results.contains(ConnectivityResult.ethernet)) {
                  connectivityStatus = ConnectivityResult.ethernet;
                } else if (results.contains(ConnectivityResult.mobile)) {
                  connectivityStatus = ConnectivityResult.mobile;
                } else if (results.contains(ConnectivityResult.other)) {
                  connectivityStatus = ConnectivityResult.other;
                }
                final connectedUpdated =
                    connectivityStatus != ConnectivityResult.none;
                connectionChanged = connected != connectedUpdated;
                connected = connectedUpdated;
                connectedTo = connectivityStatus.name;
                if (connectionChanged) await _userStatusUpdate();
              }
            },
            cancelOnError: true,
            onError: (error) {
              debugPrint('Connectivity error: ${error.toString()}');
            },
          );
    } catch (error) {
      debugPrint('Connectivity error: ${error.toString()}');
    }
  }

  bool get initCalled => _init;

  /// Stream Firebase [User] data
  Stream<User?> get streamUser => _controllerStreamUser.stream;

  /// Stream UserState
  Stream<UserStatus> get streamStatus => _controllerStreamStatus.stream;

  /// Stream serialized [UserData]
  Stream<UserData?> get streamSerialized => _controllerStreamSerialized.stream;

  /// Get User or Device language
  String get language => _language ?? 'en';

  /// Set User or Device language
  set language(String value) {
    _language = value;
  }

  /// Get User or Device language
  ThemeMode get theme => _theme ?? ThemeMode.system;

  @override
  callbackDefault(dynamic data) async {
    _controllerStreamSerialized.sink.add(data != null ? serialized : null);
    if ((_language ?? 'en') != serialized.language) {
      _language = serialized.language;
    }
    if (theme != serialized.theme) {
      _theme = serialized.theme;
    }
    await _userStatusUpdate();
  }
}
