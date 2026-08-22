import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fabric_flutter/component/user_admin.dart';
import 'package:fabric_flutter/helper/user_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/firebase_test_harness.dart';

/// Returns the dotted field paths filtered by [query].
List<String> filteredFields(Query<Map<String, dynamic>> query) {
  final raw = query.parameters['where'];
  if (raw is! Iterable) return [];
  return raw
      .whereType<Iterable>()
      .where((condition) => condition.isNotEmpty)
      .map((condition) => UserQuery.fieldPathToString(condition.first))
      .toList();
}

/// Returns the dotted field paths ordered by [query].
List<String> orderedFields(Query<Map<String, dynamic>> query) {
  final raw = query.parameters['orderBy'];
  if (raw is! Iterable) return [];
  return raw
      .whereType<Iterable>()
      .map((order) => UserQuery.fieldPathToString(order.first))
      .toList();
}

void main() {
  group('resolveUserAdminQuery', () {
    setUp(() async {
      // Arrange: mock Firebase so the Firestore instance resolves.
      await setupFirebaseForTest();
    });

    test('should scope the listing to the supplied group', () {
      // Arrange & Act
      final query = resolveUserAdminQuery(group: 'acme');

      // Assert: the group constraint is a filter, which is what a Firestore
      // `list` rule matches against.
      expect(filteredFields(query), ['groups.acme']);
      expect(UserQuery.isScoped(query), isTrue);
    });

    test('should order a group listing by the filtered field first', () {
      // Arrange & Act
      final query = resolveUserAdminQuery(group: 'acme');

      // Assert: Firestore requires the inequality field to lead the ordering.
      expect(orderedFields(query).first, 'groups.acme');
    });

    test('should read across the collection when no group is given', () {
      // Arrange & Act
      final query = resolveUserAdminQuery();

      // Assert: this is the documented unscoped path a consuming project must
      // explicitly permit. The paired scoped case above is the positive control
      // proving `isScoped` can return true at all.
      expect(filteredFields(query), isEmpty);
      expect(UserQuery.isScoped(query), isFalse);
      expect(orderedFields(query), ['name']);
    });

    test('should treat an empty group as unscoped', () {
      // Arrange & Act
      final query = resolveUserAdminQuery(group: '');

      // Assert
      expect(UserQuery.isScoped(query), isFalse);
    });

    test('should keep a caller supplied query and add the group scope', () {
      // Arrange: a consumer narrows the listing before handing it over.
      final supplied = UserQuery.collection().where('role', isEqualTo: 'admin');

      // Act
      final query = resolveUserAdminQuery(group: 'acme', query: supplied);

      // Assert: the widget never widens what the caller supplied.
      expect(filteredFields(query), containsAll(['role', 'groups.acme']));
      expect(UserQuery.isScoped(query), isTrue);
    });

    test('should honor a caller supplied query without a group', () {
      // Arrange
      final supplied = UserQuery.collection().where(
        'groups.acme',
        isNull: false,
      );

      // Act
      final query = resolveUserAdminQuery(query: supplied);

      // Assert: a consumer can stay scoped even on the group-less path.
      expect(UserQuery.isScoped(query), isTrue);
    });

    test('should not regress to the ordering-only query shape', () {
      // Arrange: the pre-fix construction, rebuilt by hand. It ordered by the
      // group field and applied no filter at all.
      final legacy = UserQuery.collection().orderBy('groups.acme');

      // Act
      final current = resolveUserAdminQuery(group: 'acme');

      // Assert: the same predicate rejects the old shape and accepts the new
      // one, which is the measured before/after this change exists to produce.
      expect(
        UserQuery.isScoped(legacy),
        isFalse,
        reason: 'ordering alone is not a constraint a list rule can require',
      );
      expect(UserQuery.isScoped(current), isTrue);

      // Assert: both still order by the same field, so the visible result set
      // is unchanged — the difference is the filter, not the documents.
      expect(orderedFields(legacy).first, orderedFields(current).first);
    });
  });
}
