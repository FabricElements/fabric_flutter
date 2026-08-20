import 'package:fabric_flutter/component/user_chip.dart';
import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:fabric_flutter/state/state_users.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/firebase_test_harness.dart';

/// Wraps [child] in a minimal app that provides a [StateUsers] instance.
///
/// Centralizing the provider setup keeps each test focused on the widget
/// behavior under verification instead of scaffolding.
Widget _wrap(StateUsers state, Widget child) {
  return ChangeNotifierProvider<StateUsers>.value(
    value: state,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('UserChip', () {
    setUp(() async {
      // Arrange: mock Firebase so StateUsers can touch FirebaseFirestore.
      await setupFirebaseForTest();
    });

    testWidgets('renders nothing when uid is null', (tester) async {
      // Arrange
      final state = StateUsers();

      // Act
      await tester.pumpWidget(_wrap(state, const UserChip(uid: null)));

      // Assert
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders the resolved name in minimal mode', (tester) async {
      // Arrange
      final state = StateUsers();
      state.usersMap['abc'] = UserData.fromJson({
        'id': 'abc',
        'firstName': 'Ada',
        'lastName': 'Lovelace',
      });

      // Act
      await tester.pumpWidget(
        _wrap(state, const UserChip(uid: 'abc', minimal: true)),
      );

      // Assert
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('renders a Chip with the resolved name', (tester) async {
      // Arrange
      final state = StateUsers();
      state.usersMap['abc'] = UserData.fromJson({
        'id': 'abc',
        'firstName': 'Grace',
        'lastName': 'Hopper',
      });

      // Act
      await tester.pumpWidget(_wrap(state, const UserChip(uid: 'abc')));

      // Assert
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
    });
  });
}
