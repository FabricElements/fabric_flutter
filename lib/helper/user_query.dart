import 'package:cloud_firestore/cloud_firestore.dart';

/// Builds account-scoped Firestore queries against the shared `user` collection.
///
/// Every user-facing list in this package reads the same collection, and each
/// call site used to express its scope with `orderBy` alone. `orderBy` does
/// restrict the returned documents to those that carry the ordered field, but it
/// is **not** a constraint a Firestore security rule can rely on: for a `list`
/// operation the rules engine matches the rule's conditions against the query's
/// *filters*, and `request.query` itself exposes only `limit`, `offset`, and
/// `orderBy`. A rule therefore cannot tell a legitimate ordered read apart from
/// an enumeration of the whole collection, which means a project cannot tighten
/// `list` while any client still issues an unfiltered query.
///
/// [UserQuery] centralizes the fix so the constraint is expressed once instead
/// of being re-derived at each call site. Scoping adds an explicit `where`
/// filter on the same field the caller already orders by, which is what lets a
/// consuming project write a `list` rule that denies unscoped reads.
///
/// See `.github/instructions/security.instructions.md` for the surrounding
/// trust-boundary rules.
class UserQuery {
  /// Names the Firestore collection that stores user documents.
  static const String collectionPath = 'user';

  /// Names the map field that holds a user's per-group role assignments.
  ///
  /// Mirrors `UserData.groups`, which maps a group identifier to the role the
  /// user holds inside that group.
  static const String groupsField = 'groups';

  /// Returns the dotted field path that stores the caller's role in [group].
  ///
  /// Throws an [ArgumentError] when [group] is empty, because an empty segment
  /// would collapse to the parent map and silently widen the scope back to the
  /// whole collection.
  static String groupFieldPath(String group) {
    if (group.isEmpty) {
      throw ArgumentError.value(group, 'group', 'group can\'t be empty');
    }
    return '$groupsField.$group';
  }

  /// Returns the base query for the shared user collection.
  ///
  /// Accepts an optional [firestore] instance so tests and multi-app consumers
  /// can target a specific [FirebaseFirestore] rather than the default one.
  /// The [CollectionReference] return type lets callers reach a single document
  /// with `doc(id)`, which is a `get` operation rather than a `list` and can
  /// therefore be gated by a much tighter rule.
  static CollectionReference<Map<String, dynamic>> collection({
    FirebaseFirestore? firestore,
  }) => (firestore ?? FirebaseFirestore.instance).collection(collectionPath);

  /// Returns [query] constrained and ordered by [fieldPath].
  ///
  /// The filter is `fieldPath != null`, which selects exactly the documents that
  /// `orderBy(fieldPath)` would already have returned — Firestore omits
  /// documents that lack the ordered field — so the visible result set does not
  /// change. What changes is that the constraint is now carried in the query's
  /// filters, where a `list` rule can require it.
  ///
  /// The inequality field must also be the first ordering, so this applies both
  /// halves together rather than leaving the caller to remember the pairing.
  /// Callers may append further orderings to the result.
  ///
  /// Throws an [ArgumentError] when [fieldPath] is empty.
  static Query<Map<String, dynamic>> scopeToField(
    Query<Map<String, dynamic>> query,
    String fieldPath,
  ) {
    if (fieldPath.isEmpty) {
      throw ArgumentError.value(
        fieldPath,
        'fieldPath',
        'fieldPath is required',
      );
    }
    return query.where(fieldPath, isNull: false).orderBy(fieldPath);
  }

  /// Returns a user query scoped to the members of [group].
  ///
  /// Combines [groupFieldPath] with [scopeToField] so a caller that knows only
  /// the group identifier gets a query a security rule can gate on. Supply
  /// [query] to scope an existing query, or leave it `null` to start from the
  /// shared user collection resolved through [firestore].
  ///
  /// Throws an [ArgumentError] when [group] is empty.
  static Query<Map<String, dynamic>> byGroup({
    required String group,
    Query<Map<String, dynamic>>? query,
    FirebaseFirestore? firestore,
  }) => scopeToField(
    query ?? collection(firestore: firestore),
    groupFieldPath(group),
  );

  /// Reports whether [query] carries a filter that constrains it to an account.
  ///
  /// Inspects the query's `where` conditions rather than its ordering, because
  /// only the filters take part in the rules-versus-query comparison that gates
  /// a `list` operation. Returns `false` for a query that is merely ordered,
  /// which is precisely the case a consuming project needs to detect before it
  /// can deny unscoped listing.
  static bool isScoped(Query<Map<String, dynamic>> query) {
    final conditions = query.parameters['where'];
    if (conditions is! Iterable) return false;
    for (final condition in conditions) {
      if (condition is! Iterable) continue;
      final parts = condition.toList();
      if (parts.length != 3) continue;
      if (fieldPathToString(parts.first).startsWith('$groupsField.')) {
        return true;
      }
    }
    return false;
  }

  /// Returns the dotted representation of a Firestore query [field].
  ///
  /// The Dart plugin normalizes a `'a.b'` string argument into a [FieldPath]
  /// before storing it in `Query.parameters`, and `FieldPath.toString()` renders
  /// as `FieldPath([a, b])`. Comparing that rendering against a dotted path
  /// silently never matches, so the components are rejoined instead.
  static String fieldPathToString(Object? field) {
    if (field is FieldPath) return field.components.join('.');
    return field.toString();
  }
}
