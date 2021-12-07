import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../serialized/user_data.dart';
import 'state_document.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

/// This is a change notifier class which keeps track of state within the widgets.
class StateUser extends StateDocument {
  User? _userObject;
  Map<String, dynamic>? _claims;
  String? _pingReference;
  DateTime _pingLast = DateTime.now().subtract(Duration(minutes: 10));
  Map<String, UserData> _usersMap = {};
  String? _lastUserGet;

  StateUser();

  @override
  String? collection = "user";

  @override
  void reset() {
    _userObject = null;
    _claims = null;
    notifyListeners();
  }

  /// [_getToken] Gets the authenticated user token and retrieves costume claims
  void _getToken() async {
    _claims = null;
    try {
      if (signedIn) {
        final token = await (_userObject!.getIdTokenResult(true));
        _claims = token.claims;
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }

  /// Set [object] with the [User] data
  set object(User? user) {
    _userObject = user;
    notifyListeners();
    // _getToken();
  }

  /// [admin] Returns "true" if the authenticated user is an admin
  bool get admin => role == "admin";

  /// [role] Returns user role
  String get role => claims["role"] ?? serialized.role;

  /// [object] Returns a [User] object
  User? get object => _userObject;

  Map<String, dynamic> get claims => _claims ?? {};

  /// Returns serialized data [UserData]
  UserData get serialized {
    UserData _userData = UserData.fromJson(data);
    _usersMap.addAll({"id": _userData});
    return _userData;
  }

  /// [signedIn] Returns "true" when the user is authenticated
  bool get signedIn => _userObject != null && _userObject?.uid == id;

  /// [roleFromData] Return an user role using [uid]
  String roleFromData({
    Map<String, dynamic>? compareData,
    String? level,
    required String? uid,
  }) {
    if (id != null && uid != null && (id == uid) && admin) {
      return role;
    }
    String _role = "user";
    if (uid == null || compareData == null || level == null) {
      return _role;
    }

    /// Get role and access level
    Map<dynamic, dynamic> _roles = compareData["roles"] ?? {};
    List<dynamic> _users = compareData["users"] ?? [];
    if (_roles.containsKey(uid) && _users.contains(uid)) {
      String _baseRole = _roles[uid];
      _role = "$level-$_baseRole";
    }
    return _role;
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
          .collection("user")
          .doc(id)
          .set({"ping": FieldValue.serverTimestamp()}, SetOptions(merge: true));
      _pingReference = reference;
    } catch (error) {
      print("user ping error: ${error.toString()}");
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
      "$uid": UserData.fromJson({"id": uid, "name": "Unknown"})
    });
    if (_lastUserGet != uid) {
      DocumentReference<Map<String, dynamic>> _documentReferenceUser =
      FirebaseFirestore.instance.collection("user").doc(uid);
      _documentReferenceUser.get().then((snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> _itemData =
          snapshot.data() as Map<String, dynamic>;
          _itemData.addAll({"id": uid});
          _usersMap.addAll({"$uid": UserData.fromJson(_itemData)});
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
}
