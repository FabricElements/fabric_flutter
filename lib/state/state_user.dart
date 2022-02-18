import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/helper/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../serialized/user_data.dart';
import 'state_document.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

/// This is a change notifier class which keeps track of state within the widgets.
class StateUser extends StateDocument {
  StateUser();

  @override
  String? collection = 'user';

  /// State specific functionality
  User? _userObject;
  Map<String, dynamic>? _claims;
  String? _pingReference;
  DateTime _pingLast = DateTime.now().subtract(Duration(minutes: 10));
  Map<String, UserData> _usersMap = {};
  String? _lastUserGet;
  bool _init = false;
  String _language = "en";

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

  /// Get user token
  String? get token => _token;

  /// [_getToken] Gets the authenticated user token and retrieves costume claims
  void _getToken(User? userObject) async {
    _claims = null;
    _token = null;
    if (userObject != null) {
      try {
        final tokenResult = await userObject.getIdTokenResult(true);
        _token = tokenResult.token;
        _claims = tokenResult.claims;
        notifyListeners();
      } catch (e) {
        print(e);
      }
    }
  }

  /// Set [object] with the [User] data
  set object(User? user) {
    _userObject = user;
    notifyListeners();
    _getToken(user);
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
    UserData _userData = UserData.fromJson(data);
    _usersMap.addAll({'id': _userData});
    return _userData;
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
    String _role = compareData?['role'] ?? role ?? 'user';
    if (level == null || levelId == null || compareData == null) {
      return _role;
    }

    /// Get role and access level
    Map<dynamic, dynamic> _levelRole = compareData[level] ?? {};
    if (_levelRole.containsKey(levelId)) {
      String _baseRole = _levelRole[levelId];
      if (clean) return _baseRole;
      _role = '$level-$_baseRole';
    }
    return _role;
  }

  /// [roleFromData] Return the current user role
  String roleFromData({
    String? level,
    String? levelId,

    /// [clean] returns the role without the [level]
    bool clean = false,
  }) {
    String _role = role;
    if (id != null && admin) {
      return _role;
    }
    if (level != null || levelId != null)
      assert(level != null && levelId != null,
          "level and levelId must be initialized.");
    if (level == null || levelId == null || data == null) {
      return _role;
    }
    return roleFromDataAny(
      level: level,
      levelId: levelId,
      compareData: data,
      role: _role,
      clean: clean,
    );
  }

  /// Ping user
  void ping(String reference) async {
    if (reference == _pingReference || !signedIn || data.isEmpty) return;
    _pingLast = serialized.ping ?? _pingLast;
    DateTime _timeRef = DateTime.now().subtract(Duration(minutes: 1));
    if (_pingLast.isAfter(_timeRef)) return;
    _pingLast = DateTime.now(); // Define before saving because it's async
    try {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(id)
          .set({'ping': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      _pingReference = reference;
    } catch (error) {
      print('user ping error: ${error.toString()}');
    }
  }

  /// Returns list of [users]
  List<UserData> get users {
    List<UserData> _endUsers = [];
    _usersMap.forEach((key, value) {
      _endUsers.add(value);
    });
    return _endUsers;
  }

  /// [usersMap] Returns a map of [users]
  Map<String, UserData> get usersMap => _usersMap;

  /// [getUser] returns [UserData] from uid
  UserData getUser(String uid) {
    if (_usersMap.containsKey(uid)) {
      return _usersMap[uid]!;
    }
    _usersMap.addAll({
      '$uid': UserData.fromJson({'id': uid, 'name': 'Unknown'})
    });
    if (_lastUserGet != uid) {
      DocumentReference<Map<String, dynamic>> _documentReferenceUser =
      FirebaseFirestore.instance.collection('user').doc(uid);
      _documentReferenceUser.get().then((snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> _itemData =
          snapshot.data() as Map<String, dynamic>;
          _itemData.addAll({'id': uid});
          _usersMap.addAll({'$uid': UserData.fromJson(_itemData)});
          notifyListeners();
        }
      });
    }
    return _usersMap[uid]!;
  }

  /// Sign Out user
  void signOut() async {
    await _auth.signOut();
    this.clear();
  }

  /// [accessByRole] displays content only if the the role matches for current user
  bool accessByRole({
    String? level,
    String? levelId,
    List<String> roles = const ['admin'],
  }) {
    String _role = roleFromData(level: level, levelId: levelId);
    return roles.contains(_role);
  }

  /// Refresh auth state
  _refreshAuth(User? userObject) async {
    String? uid = userObject?.uid ?? null;
    id = uid;
    object = userObject ?? null;
    _init = true;
    await Future.delayed(Duration(milliseconds: 300));
    _controllerStreamUser.sink.add(userObject);
  }

  /// Init app and prevent duplicated calls
  void init() {
    if (_init) return;
    Utils.getLanguage().then((value) {
      _language = value;
      _controllerStreamLanguage.sink.add(_language);
    });
    _auth.userChanges().listen((User? userObject) => _refreshAuth(userObject));
  }

  /// Stream Firebase [User] data
  Stream<User?> get streamUser => _controllerStreamUser.stream;

  /// Stream serialized [UserData]
  Stream<UserData?> get streamSerialized => _controllerStreamSerialized.stream;

  /// Stream [language]
  Stream<String> get streamLanguage => _controllerStreamLanguage.stream;

  /// Get User or Device [language]
  String get language => data != null ? serialized.language : _language;

  @override
  Function(dynamic data) callback = (dynamic data) {
    if (StateUser()._language != StateUser().serialized.language)
      StateUser()._controllerStreamLanguage.sink.add(StateUser().language);
    StateUser()
        ._controllerStreamSerialized
        .sink
        .add(data != null ? StateUser().serialized : null);
  };
}
