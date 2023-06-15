import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../helper/user_roles.dart';
import '../helper/utils.dart';
import '../serialized/user_data.dart';
import '../serialized/user_status.dart';
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
  final Map<String, UserData> _usersMap = {};
  String? _lastUserGet;
  bool _init = false;
  String? _language;
  Brightness? _brightness;

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
    _userObject = null;
    _claims = null;
    _token = null;
    _userStatusUpdate();
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
        _userStatusUpdate();
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

  /// Set object with the [User] data
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
    _userStatus = status;
    if (_userStatus != null) {
      _userStatus!.timestamp = DateTime.now();
      _controllerStreamStatus.sink.add(_userStatus!);
    }
  }

  /// Update user status data
  _userStatusUpdate() {
    userStatus = UserStatus(
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
    _userStatusUpdate();
    _controllerStreamUser.sink.add(userObject);
    if (_userObject != userObject) {
      try {
        // Call before _controllerStreamStatus to prevent unauthenticated calls
        await _getToken(userObject);
      } catch (e) {
        //-
      }
    }
  }

  /// Init app and prevent duplicated calls
  void init() {
    if (_init) return;
    Utils.getLanguage().then((value) {
      _language = value;
    }).catchError((error) {});

    _auth.userChanges().listen((value) {
      _init = true;
      _refreshAuth(value);
    }, onError: (e) => error = e.toString());
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
  Brightness get brightness => _brightness ?? Brightness.light;

  @override
  callbackDefault(dynamic data) {
    final _newUserData = UserData.fromJson(data);
    bool willUpdateStatus = false;
    if ((_language ?? 'en') != _newUserData.language) {
      _language = _newUserData.language;
      willUpdateStatus = true;
    }
    if ((_brightness ?? Brightness.light) != _newUserData.brightness) {
      _brightness = _newUserData.brightness;
      willUpdateStatus = true;
    }
    if (willUpdateStatus) _userStatusUpdate();
    _controllerStreamSerialized.sink.add(data != null ? serialized : null);
  }
}
