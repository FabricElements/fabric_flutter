import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  final Map<String, UserData> _usersMap = {};
  String? _lastUserGet;
  bool _init = false;
  String? _language;
  ThemeMode? _theme;

  /// More at [streamStatus]
  /// ignore: close_sinks
  final _controllerStreamStatus = StreamController<UserStatus>.broadcast();

  /// More at [streamUser]
  /// ignore: close_sinks
  final _controllerStreamUser = StreamController<User?>.broadcast();

  /// More at [streamSerialized]
  /// ignore: close_sinks
  final _controllerStreamSerialized = StreamController<UserData?>.broadcast();

  @override
  void clearAfter() {
    _theme = null;
    _userObject = null;
    _claims = null;
    _token = null;
    if (initialized) notifyListeners();
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
        if (kDebugMode) print(e);
      }
    }
    if (userObject != null && initialized) notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
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
  UserData get serialized {
    UserData userDataSerialized = UserData.fromJson(data ?? {});
    if (data != null) {
      _usersMap.addAll({'id': userDataSerialized});
    }
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
    if (!kReleaseMode) return;
    if (reference == _pingReference || !signedIn || data.isEmpty) return;
    _pingLast = serialized.ping ?? _pingLast;
    DateTime timeRef = DateTime.now().subtract(const Duration(minutes: 1));
    if (_pingLast.isAfter(timeRef)) return;
    _pingLast = DateTime.now(); // Define before saving because it's async
    try {
      await ref?.set(
        {'ping': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      _pingReference = reference;
    } catch (error) {
      if (kDebugMode) print('User ping error: ${error.toString()}');
    }
  }

  /// Returns list of [users]
  List<UserData> get users {
    List<UserData> usersList = [];
    _usersMap.forEach((key, value) {
      usersList.add(value);
    });
    return usersList;
  }

  /// [usersMap] Returns a map of [users]
  Map<String, UserData> get usersMap => _usersMap;

  /// [getUser] returns [UserData] from uid
  UserData getUser(String uid) {
    if (_usersMap.containsKey(uid)) {
      return _usersMap[uid]!;
    }
    _usersMap.addAll({
      uid: UserData.fromJson({'id': uid, 'name': 'Unknown'})
    });
    if (_lastUserGet != uid) {
      final userDocRef = db.collection('user').doc(uid);
      userDocRef.get().then((snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> itemData =
              snapshot.data() as Map<String, dynamic>;
          itemData.addAll({'id': uid});
          _usersMap.addAll({uid: UserData.fromJson(itemData)});
          if (initialized) notifyListeners();
        }
      }).onError((error, stackTrace) {
        if (kDebugMode) print('getUser: ${error.toString()}');
      });
    }
    return _usersMap[uid]!;
  }

  /// Sign Out user
  void signOut() async {
    await cancel();
    await _auth.signOut();
    clear(notify: true);
  }

  /// [accessByRole] displays content only if the the role matches for current user
  bool accessByRole({
    String? group,
    List<String> roles = const ['admin'],
  }) {
    return roles.contains(roleFromData(group: group));
  }

  /// User Status
  UserStatus? _userStatus;

  /// Get userStatus
  UserStatus? get userStatus => _userStatus;

  /// Set userStatus
  set userStatus(UserStatus? status) {
    final previous = _userStatus?.toJson() ?? {};
    if (status != null && !mapEquals(status.toJson(), previous)) {
      _userStatus = status;
      _controllerStreamStatus.sink.add(status);
    }
  }

  /// Update user status data
  _userStatusUpdate() async {
    userStatus = UserStatus(
      role: role,
      admin: admin,
      signedIn: signedIn,
      uid: object?.uid,
      language: language,
      theme: theme,
    );
  }

  /// Refresh auth state
  _refreshAuth(User? userObject) async {
    if (userObject == null) {
      clear(notify: true);
      await _userStatusUpdate();
      return;
    }
    if (object == null ||
        object.toString().hashCode != userObject.toString().hashCode) {
      ref = db.collection('user').doc(userObject.uid);
      object = userObject;
      try {
        // Call before _controllerStreamStatus to prevent unauthenticated calls
        await _getToken(userObject);
      } catch (e) {
        await _userStatusUpdate();
      }
    }
  }

  /// Init app and prevent duplicated calls
  void init() {
    if (_init) return;
    _init = true;
    Utils.getLanguage()
        .then((value) => _language = value)
        .catchError((error) => '');
    _auth
        .userChanges()
        .listen(_refreshAuth, onError: (e) => error = e.toString());
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

  /// Get User or Device language
  ThemeMode get theme => _theme ?? ThemeMode.system;

  @override
  callbackDefault(dynamic data) async {
    _controllerStreamSerialized.sink.add(data != null ? serialized : null);
    if (loading || data == null) return;
    loading = true;
    bool willUpdateStatus = false;
    if ((_language ?? 'en') != serialized.language) {
      _language = serialized.language;
      willUpdateStatus = true;
    }
    if (theme != serialized.theme) {
      _theme = serialized.theme;
      willUpdateStatus = true;
    }
    if (willUpdateStatus && _init && initialized) await _userStatusUpdate();
    loading = false;
  }
}
