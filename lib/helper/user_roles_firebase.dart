import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../serialized/user_data.dart';

class UserRolesFirebase {
  static onAdd(UserData user, {String? group}) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-add');
    Map<String, dynamic> dataFinal = {
      ...user.toJson(),
      'group': group,
    };
    return callable.call(dataFinal);
  }

  static onRemove(UserData user, {String? group}) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-remove');
    Map<String, dynamic> dataFinal = {
      ...user.toJson(),
      'group': group,
    };
    print(dataFinal);
    return callable.call(dataFinal);
  }

  static onUpdate(UserData user, {String? group}) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-role');
    Map<String, dynamic> dataFinal = {
      ...user.toJson(),
      'group': group,
    };
    return callable.call(dataFinal);
  }

  static Future<List<Map<String, dynamic>>> getUsers({
    String? group,
  }) async {
    if (group != null) {
      assert(group.isNotEmpty, 'group can\'t be empty');
    }
    Query baseQuery = FirebaseFirestore.instance.collection('user');
    Query query = baseQuery;

    /// Order By role for global users, the role key is only available for parent users
    query = query.orderBy('role');
    bool fromCollection = group != null && group.isNotEmpty;
    if (fromCollection) {
      query = baseQuery.orderBy('roles.$group');
    }
    final snapshot = await query.get();
    final data = snapshot.docs.map((userDocument) {
      Map<String, dynamic> userData =
          userDocument.data()! as Map<String, dynamic>;
      userData.addAll({'id': userDocument.id});
      return userData;
    }).toList();
    return data;
  }
}
