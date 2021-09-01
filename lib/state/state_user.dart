import 'package:firebase_auth/firebase_auth.dart';

import '../serialized/user_data.dart';
import 'state_document.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

/// This is a change notifier class which keeps track of state within the widgets.
class StateUser extends StateDocument {
  User? _userObject;
  Map<String, dynamic>? _claims;

  StateUser();

  @override
  String collection = "user";

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
      }
    } catch (e) {
      print(e);
    }
    notifyListeners();
  }

  /// Set [object] with the [User] data
  set object(User? user) {
    _userObject = user;
    notifyListeners();
    _getToken();
  }

  /// [admin] Returns "true" if the authenticated user is an admin
  bool get admin => serialized.role == "admin";

  /// [object] Returns a [User] object
  User? get object => _userObject;

  Map<String, dynamic> get claims => _claims ?? {};

  /// Returns serialized data [UserData]
  UserData get serialized => UserData.fromJson(data);

  /// [signedIn] Returns "true" when the user is authenticated
  bool get signedIn => _userObject != null && _userObject?.uid == id;

  /// [roleFromData] Return an user role using [uid]
  String roleFromData({
    Map<String, dynamic>? compareData,
    String? level,
    required String? uid,
  }) {
    if (id != null &&
        uid != null &&
        (id == uid) &&
        serialized.role == "admin") {
      return serialized.role;
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

  /// Sign Out user
  void signOut() async {
    await _auth.signOut();
    this.clear();
  }
}
