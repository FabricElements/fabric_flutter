import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../serialized/user_data.dart';

class UserRolesFirebase {
  static onAdd(UserData user, {String? group, String? groupId}) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-add');
    Map<String, dynamic> dataFinal = {
      ...user.toJson(),
      'group': group,
      'groupId': groupId,
    };
    return callable.call(dataFinal);
  }

  static onRemove(UserData user, {String? group, String? groupId}) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-remove');
    Map<String, dynamic> dataFinal = {
      ...user.toJson(),
      'group': group,
      'groupId': groupId,
    };
    print(dataFinal);
    return callable.call(dataFinal);
  }

  static onUpdate(UserData user, {String? group, String? groupId}) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-role');
    Map<String, dynamic> dataFinal = {
      ...user.toJson(),
      'group': group,
      'groupId': groupId,
    };
    return callable.call(dataFinal);
  }

  static Future<List<Map<String, dynamic>>> getUsers({
    String? group,
    String? groupId,
  }) async {
    if (group != null || groupId != null) {
      assert(group != null && groupId != null,
          'collection and document can\'t be null when including one of them.');
    }
    Query baseQuery = FirebaseFirestore.instance.collection('user');
    Query query = baseQuery;

    /// Order By role for global users, the role key is only available for parent users
    query = query.orderBy('role');
    bool fromCollection = group != null && groupId != null;
    if (fromCollection) {
      query = baseQuery.orderBy('$group.$groupId');
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
