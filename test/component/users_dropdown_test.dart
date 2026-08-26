import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/component/users_dropdown.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/state/state_users.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/debounce.dart';
import '../support/fake_state_users.dart';
import '../support/firebase_test_harness.dart';

/// Pumps [child] with a [StateUsers] provider and loaded localization.
///
/// Wiring localization and Provider once keeps each test focused on the
/// dropdown behavior rather than repeating scaffold setup.
Future<void> _pump(WidgetTester tester, StateUsers state, Widget child) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<StateUsers>.value(
      value: state,
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
        supportedLocales: const [Locale('en', 'US')],
        home: Scaffold(body: child),
      ),
    ),
  );
  await pumpDebounce(tester);
}

void main() {
  group('UsersDropdown', () {
    setUp(() async {
      // Arrange: mock Firebase so StateUsers can touch FirebaseFirestore.
      await setupFirebaseForTest();
    });

    testWidgets('renders a fixed-height placeholder when there are no users', (
      tester,
    ) async {
      // Arrange
      final state = FakeStateUsers();

      // Act
      await _pump(tester, state, const UsersDropdown(uid: null));

      // Assert
      expect(find.byType(InputData), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('builds a dropdown of options from serialized users', (
      tester,
    ) async {
      // Arrange
      final state = FakeStateUsers();
      state.data = [
        {'id': 'b', 'firstName': 'Bob', 'lastName': 'Stone'},
        {'id': 'a', 'firstName': 'Ada', 'lastName': 'Byron'},
      ];

      // Act
      await _pump(tester, state, const UsersDropdown(uid: null));

      // Assert – dropdown is rendered instead of the empty placeholder.
      expect(find.byType(InputData), findsOneWidget);
    });

    test('serialized returns users sorted by name', () {
      // Arrange
      final state = FakeStateUsers();
      state.data = [
        {'id': 'b', 'firstName': 'Bob', 'lastName': 'Stone'},
        {'id': 'a', 'firstName': 'Ada', 'lastName': 'Byron'},
      ];

      // Act
      final names = state.serialized.map((user) => user.name).toList();

      // Assert
      expect(names, ['Ada Byron', 'Bob Stone']);
    });

    testWidgets(
      'keeps rendering across rebuilds without leaking a controller',
      (tester) async {
        // Arrange
        final state = FakeStateUsers();
        state.data = [
          {'id': 'a', 'firstName': 'Ada', 'lastName': 'Byron'},
        ];

        // Act: pump, then force additional rebuilds of the same widget tree.
        await _pump(tester, state, const UsersDropdown(uid: null));
        await tester.pump();
        await tester.pump();

        // Assert: still renders a single dropdown, no exceptions on rebuild.
        expect(find.byType(InputData), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
