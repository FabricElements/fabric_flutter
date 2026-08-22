import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../serialized/user_data.dart';
import 'user_query.dart';

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
  /// constrained and ordered by `roles.<group>` so role-based lists remain
  /// predictable.
  ///
  /// > 🔒 **Scope.** A group-scoped lookup now carries an explicit
  /// > `roles.<group> != null` filter in addition to its ordering. The returned
  /// > documents are unchanged, because Firestore already omitted documents that
  /// > lack the ordered field, but the constraint is now visible to a Firestore
  /// > `list` rule. A **global** lookup — [group] `null` and no [query] — still
  /// > reads across the whole collection and therefore requires the consuming
  /// > project to permit unscoped listing. Pass [group], or pass a pre-scoped
  /// > [query], whenever the caller only needs one account's users.
  ///
  /// > **Performance warning:** when [limit] is `null` this reads *every*
  /// > document matched by the query. On a large collection that is an
  /// > expensive, unbounded read in billed document reads, bandwidth, and
  /// > deserialization time. Pass [limit] to cap the result set, or drive the
  /// > list through `StateCollection`, which paginates automatically.
  ///
  /// [limit] caps the number of documents fetched. It defaults to `null`, which
  /// preserves the previous unbounded behavior for existing callers.
  ///
  /// [query] replaces the collection reference this helper would otherwise
  /// build, letting a consumer supply a query already narrowed to the accounts
  /// the caller belongs to. Ordering and [limit] are applied on top of it.
  static Future<List<Map<String, dynamic>>> getUsers({
    String? group,
    int? limit,
    Query<Map<String, dynamic>>? query,
  }) async {
    if (group != null) {
      assert(group.isNotEmpty, 'group can\'t be empty');
    }
    assert(limit == null || limit > 0, 'limit must be greater than zero');
    final Query<Map<String, dynamic>> baseQuery =
        query ?? UserQuery.collection();
    Query<Map<String, dynamic>> resolved;
    bool fromCollection = group != null && group.isNotEmpty;
    if (fromCollection) {
      // Scope to the group with an explicit filter so a `list` rule can require
      // it. The field stays `roles.<group>` to preserve this helper's existing
      // result set; see `UserQuery` for why ordering alone is not enough.
      resolved = UserQuery.scopeToField(baseQuery, 'roles.$group');
    } else {
      /// Order By role for global users, the role key is only available for parent users
      resolved = baseQuery.orderBy('role');
    }
    if (limit != null) resolved = resolved.limit(limit);
    final Query<Map<String, dynamic>> finalQuery = resolved;
    final snapshot = await finalQuery.get();
    final data = snapshot.docs.map((userDocument) {
      Map<String, dynamic> userData = userDocument.data();
      userData.addAll({'id': userDocument.id});
      return userData;
    }).toList();
    return data;
  }
}
