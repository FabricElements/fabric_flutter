import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../serialized/user_data.dart';

/// Bridges role-management actions to Firebase services.
///
/// This helper keeps Cloud Function names and Firestore queries in one place so
/// the rest of the app can add, remove, update, and list role assignments
/// without duplicating backend integration details.
class UserRolesFirebase {
  /// Calls the Firebase function that adds [user] to a role or [group].
  static Future<HttpsCallableResult> onAdd(UserData user, {String? group}) {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'user-actions-add',
    );
    Map<String, dynamic> dataFinal = {...user.toJson(), 'group': group};
    return callable.call(dataFinal);
  }

  /// Calls the Firebase function that removes [user] from a role or [group].
  static Future<HttpsCallableResult> onRemove(UserData user, {String? group}) {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'user-actions-remove',
    );
    Map<String, dynamic> dataFinal = {...user.toJson(), 'group': group};
    return callable.call(dataFinal);
  }

  /// Calls the Firebase function that updates [user] role data.
  ///
  /// When [group] is supplied, the backend can scope the change to a specific
  /// nested role entry instead of the user's global role.
  static Future<HttpsCallableResult> onUpdate(UserData user, {String? group}) {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'user-actions-role',
    );
    Map<String, dynamic> dataFinal = {...user.toJson(), 'group': group};
    return callable.call(dataFinal);
  }

  /// Returns Firestore user documents as plain maps, optionally scoped by [group].
  ///
  /// Global lookups are ordered by `role`, while group-scoped lookups are
  /// ordered by `roles.<group>` so role-based lists remain predictable.
  static Future<List<Map<String, dynamic>>> getUsers({String? group}) async {
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
