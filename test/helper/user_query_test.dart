import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/helper/user_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/firebase_test_harness.dart';

/// Returns the `where` conditions carried by [query] as comparable triples.
///
/// The Firestore Dart plugin stores conditions as `[field, operator, value]`
/// entries under the `where` key of `Query.parameters`, so reading them back is
/// how a test can prove a constraint is a *filter* rather than an ordering. The
/// field is normalized to a dotted path because the plugin converts a `'a.b'`
/// argument into a `FieldPath` whose `toString()` is `FieldPath([a, b])`.
List<List<Object?>> whereConditions(Query<Map<String, dynamic>> query) {
  final raw = query.parameters['where'];
  if (raw is! Iterable) return [];
  return raw.whereType<Iterable>().map((condition) {
    final parts = condition.toList();
    if (parts.isEmpty) return parts;
    return <Object?>[
      UserQuery.fieldPathToString(parts.first),
      ...parts.skip(1),
    ];
  }).toList();
}

/// Returns the ordered field paths carried by [query].
List<String> orderByFields(Query<Map<String, dynamic>> query) {
  final raw = query.parameters['orderBy'];
  if (raw is! Iterable) return [];
  return raw
      .whereType<Iterable>()
      .map((order) => UserQuery.fieldPathToString(order.first))
      .toList();
}

void main() {
  group('UserQuery', () {
    setUp(() async {
      // Arrange: mock Firebase so the Firestore instance resolves.
      await setupFirebaseForTest();
    });

    group('groupFieldPath', () {
      test('should build a dotted path under the groups map', () {
        // Arrange & Act
        final path = UserQuery.groupFieldPath('acme');

        // Assert
        expect(path, 'groups.acme');
      });

      test('should reject an empty group', () {
        // Arrange & Act & Assert: an empty segment would collapse to the parent
        // map and silently widen the scope back to the whole collection.
        expect(
          () => UserQuery.groupFieldPath(''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('scopeToField', () {
      test('should add a filter, not only an ordering', () {
        // Arrange
        final base = UserQuery.collection();

        // Act
        final scoped = UserQuery.scopeToField(base, 'groups.acme');

        // Assert: the constraint must appear in `where`, because a Firestore
        // `list` rule matches against filters and cannot see an ordering.
        final conditions = whereConditions(scoped);
        expect(conditions, hasLength(1));
        expect(conditions.single.first, 'groups.acme');
        expect(conditions.single[1], '!=');
        expect(conditions.single[2], isNull);
      });

      test('should order by the filtered field first', () {
        // Arrange
        final base = UserQuery.collection();

        // Act
        final scoped = UserQuery.scopeToField(base, 'groups.acme');

        // Assert: Firestore requires the inequality field to lead the ordering.
        expect(orderByFields(scoped).first, 'groups.acme');
      });

      test('should reject an empty field path', () {
        // Arrange
        final base = UserQuery.collection();

        // Act & Assert
        expect(
          () => UserQuery.scopeToField(base, ''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('isScoped', () {
      test('should report false for an ordered but unfiltered query', () {
        // Arrange
        final unscoped = UserQuery.collection().orderBy('name');

        // Act
        final result = UserQuery.isScoped(unscoped);

        // Assert: ordering alone reads across the whole collection.
        expect(result, isFalse);
      });

      test('should report true for a group-scoped query', () {
        // Arrange: positive control for the assertion above. Without it, the
        // `isFalse` expectation could pass simply because `isScoped` never
        // returns true — for example if the parameter shape changed.
        final scoped = UserQuery.byGroup(group: 'acme');

        // Act
        final result = UserQuery.isScoped(scoped);

        // Assert
        expect(result, isTrue);
      });

      test('should report false for a filter outside the groups map', () {
        // Arrange: a filter on an unrelated field does not scope to an account.
        final query = UserQuery.collection().where('role', isEqualTo: 'admin');

        // Act & Assert
        expect(UserQuery.isScoped(query), isFalse);
      });
    });

    group('byGroup', () {
      test('should scope to the supplied group', () {
        // Arrange & Act
        final scoped = UserQuery.byGroup(group: 'acme');

        // Assert
        final conditions = whereConditions(scoped);
        expect(conditions.single.first, 'groups.acme');
      });

      test('should preserve a caller supplied query', () {
        // Arrange: a consumer may pass a query already narrowed elsewhere.
        final base = UserQuery.collection().where('role', isEqualTo: 'admin');

        // Act
        final scoped = UserQuery.byGroup(group: 'acme', query: base);

        // Assert: both the caller's filter and the group scope survive.
        final fields = whereConditions(
          scoped,
        ).map((condition) => condition.first).toList();
        expect(fields, containsAll(<Object?>['role', 'groups.acme']));
      });

      test('should reject an empty group', () {
        // Arrange & Act & Assert
        expect(
          () => UserQuery.byGroup(group: ''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('collection', () {
      test('should target the shared user collection', () {
        // Arrange & Act
        final collection = UserQuery.collection();

        // Assert
        expect(collection.id, UserQuery.collectionPath);
      });

      test('should expose a document reference for get operations', () {
        // Arrange & Act: resolving one document is a `get`, not a `list`, which
        // is what lets a project deny collection listing outright.
        final doc = UserQuery.collection().doc('abc');

        // Assert
        expect(doc.id, 'abc');
        expect(doc.path, '${UserQuery.collectionPath}/abc');
      });
    });
  });
}
