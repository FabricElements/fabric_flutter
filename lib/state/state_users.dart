import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../helper/log_color.dart';
import '../serialized/user_data.dart';
import 'state_collection.dart';

final db = FirebaseFirestore.instance;

class StateUsers extends StateCollection {
  @override
  int limitDefault = 20;

  @override
  List<UserData> get serialized {
    if (data == null) return [];
    List<UserData> items = (data as List<dynamic>)
        .map((value) => UserData.fromJson(value))
        .toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  /// Map of users.
  /// Includes all users from the query request and individual [getUser] calls
  final Map<String, UserData> _usersMap = {};

  /// Returns a map of [users]
  Map<String, UserData> get usersMap => _usersMap;

  /// Returns [UserData] from uid
  UserData getUser(String uid) {
    if (_usersMap.containsKey(uid)) {
      return _usersMap[uid]!;
    }
    _usersMap.addAll({
      uid: UserData.fromJson({'id': uid, 'name': 'Unknown'})
    });
    final userDocRef = db.collection('user').doc(uid);
    userDocRef.get().then((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> itemData = snapshot.data() as Map<String, dynamic>;
        itemData.addAll({'id': uid});
        _usersMap.addAll({uid: UserData.fromJson(itemData)});
        if (initialized) notifyListeners();
      }
    }).onError((error, stackTrace) {
      debugPrint(LogColor.error('StateUsers.getUser: ${error.toString()}'));
    });
    return _usersMap[uid]!;
  }

  /// Returns list of users
  List<UserData> get users => _usersMap.values.toList();

  @override
  void notifyListeners() {
    /// Add users to the _usersMap variable
    for (UserData user in serialized) {
      _usersMap[user.id] = user;
    }
    super.notifyListeners();
  }
}
