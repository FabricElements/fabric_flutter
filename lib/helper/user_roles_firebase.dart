import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../serialized/add_user_data.dart';

class UserRolesFirebase {
  static onAdd(AddUserData options) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-add');
    return callable.call(options.toJson());
  }

  static onRemove(Map<String, dynamic> options) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-remove');
    return callable.call(options);
  }

  static onUpdate(Map<String, dynamic> options) {
    final callable =
        FirebaseFunctions.instance.httpsCallable('user-actions-role');
    return callable.call(options);
  }

  static Future<List<Map<String, dynamic>>> getUsers({
    String? collection,
    String? id,
  }) async {
    if (collection != null || id != null) {
      assert(collection != null && id != null,
          'collection and document can\'t be null when including one of them.');
    }
    Query baseQuery = FirebaseFirestore.instance.collection('user');
    Query query = baseQuery;

    /// Order By role for global users, the role key is only available for parent users
    query = query.orderBy('role');
    bool fromCollection = collection != null && id != null;
    if (fromCollection) {
      query = baseQuery.orderBy('$collection.$id');
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
