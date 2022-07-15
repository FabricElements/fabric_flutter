library fabric_flutter;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../helper/utils.dart';
import '../serialized/user_data.dart';
import 'state_document.dart';

final _auth = FirebaseAuth.instance;

/// This is a change notifier class which keeps track of state within the widgets.
class StateUser extends StateDocument {
  StateUser();

  @override
  String? collection = 'user';

  /// State specific functionality
  User? _userObject;
  Map<String, dynamic>? _claims;
  String? _pingReference;
  DateTime _pingLast = DateTime.now().subtract(const Duration(minutes: 10));
  Map<String, UserData> _usersMap = {};
  String? _lastUserGet;
  bool _init = false;
  String _language = 'en';

  /// More at [streamStatus]
  /// ignore: close_sinks
  final _controllerStreamStatus = StreamController<UserStatus>.broadcast();

  /// More at [streamUser]
  /// ignore: close_sinks
  final _controllerStreamUser = StreamController<User?>.broadcast();

  /// More at [streamSerialized]
  /// ignore: close_sinks
  final _controllerStreamSerialized = StreamController<UserData?>.broadcast();

  /// More at [streamLanguage]
  /// ignore: close_sinks
  final _controllerStreamLanguage = StreamController<String>.broadcast();

  @override
  void clearAfter() {
    _userObject = null;
    _claims = null;
    _token = null;
    notifyListeners();
  }

  /// More at [token]
  String? _token;

  /// Gets the authenticated user token and retrieves costume claims
  _getToken(User? userObject) async {
    _claims = null;
    _token = null;
    if (userObject != null) {
      try {
        final tokenResult = await userObject.getIdTokenResult(true);
        _token = tokenResult.token;
        _claims = tokenResult.claims;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }

  /// Get user token
  String? get token {
    if (_token == null) _getToken(object);
    return _token;
  }

  /// Set [object] with the [User] data
  set object(User? user) {
    _userObject = user;
    notifyListeners();
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
  bool get signedIn => _userObject != null && _userObject?.uid == id;

  /// [roleFromDataAny] Return an user role using [uid]
  String roleFromDataAny({
    Map<String, dynamic>? compareData,
    String? level,
    String? levelId,
    String? role,

    /// [clean] returns the role without the [level]
    bool clean = false,
  }) {
    String roleDefault = compareData?['role'] ?? role ?? 'user';
    if (level == null || levelId == null || compareData == null) {
      return roleDefault;
    }

    /// Get role and access level
    Map<dynamic, dynamic> levelRole = compareData[level] ?? {};
    if (levelRole.containsKey(levelId)) {
      String baseRole = levelRole[levelId];
      if (clean) return baseRole;
      roleDefault = '$level-$baseRole';
    }
    return roleDefault;
  }

  /// [roleFromData] Return the current user role
  String roleFromData({
    String? level,
    String? levelId,

    /// [clean] returns the role without the [level]
    bool clean = false,
  }) {
    if (id != null && admin) {
      return role;
    }
    if (level != null || levelId != null) {
      assert(
        level != null && levelId != null,
        'level and levelId must be initialized.',
      );
    }
    if (level == null || levelId == null || data == null) {
      return role;
    }
    return roleFromDataAny(
      level: level,
      levelId: levelId,
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
      await FirebaseFirestore.instance
          .collection('user')
          .doc(id)
          .set({'ping': FieldValue.serverTimestamp()}, SetOptions(merge: true));
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
      DocumentReference<Map<String, dynamic>> documentReferenceUser =
          FirebaseFirestore.instance.collection('user').doc(uid);
      documentReferenceUser.get().then((snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> itemData =
              snapshot.data() as Map<String, dynamic>;
          itemData.addAll({'id': uid});
          _usersMap.addAll({uid: UserData.fromJson(itemData)});
          notifyListeners();
        }
      });
    }
    return _usersMap[uid]!;
  }

  /// Sign Out user
  void signOut() async {
    await _auth.signOut();
    clear();
  }

  /// [accessByRole] displays content only if the the role matches for current user
  bool accessByRole({
    String? level,
    String? levelId,
    List<String> roles = const ['admin'],
  }) {
    return roles.contains(roleFromData(level: level, levelId: levelId));
  }

  UserStatus get userStatus {
    return UserStatus(
      role: role,
      admin: admin,
      signedIn: signedIn,
      uid: _userObject?.uid,
    );
  }

  /// Refresh auth state
  _refreshAuth(User? userObject) async {
    _init = true;
    if (id != userObject?.uid) id = userObject?.uid;
    object = userObject;
    _controllerStreamUser.sink.add(userObject);
    if (_userObject != userObject) {
      try {
        // Call before _controllerStreamStatus to prevent unauthenticated calls
        await _getToken(userObject);
      } catch (e) {
        //-
      }
    }
    _controllerStreamStatus.sink.add(userStatus);
  }

  /// Init app and prevent duplicated calls
  void init() {
    if (_init) return;
    _init = true;
    _auth.userChanges().listen((value) => _refreshAuth(value),
        onError: (e) => error = e.toString());
    Utils.getLanguage().then((value) {
      _language = value;
      _controllerStreamLanguage.sink.add(_language);
    }).catchError((error) {
      if (kDebugMode) print(error);
    });
  }

  /// Stream Firebase [User] data
  Stream<User?> get streamUser => _controllerStreamUser.stream;

  /// Stream UserState
  Stream<UserStatus> get streamStatus => _controllerStreamStatus.stream;

  /// Stream serialized [UserData]
  Stream<UserData?> get streamSerialized => _controllerStreamSerialized.stream;

  /// Stream [language]
  Stream<String> get streamLanguage => _controllerStreamLanguage.stream;

  /// Get User or Device [language]
  String get language => data != null ? serialized.language : _language;

  @override
  callbackDefault(dynamic data) {
    if (StateUser()._language != StateUser().serialized.language) {
      StateUser()._controllerStreamLanguage.sink.add(StateUser().language);
      StateUser()
          ._controllerStreamSerialized
          .sink
          .add(data != null ? StateUser().serialized : null);
    }
  }
}
