import 'package:fabric_flutter/component/users_dropdown.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:fabric_flutter/state/state_users.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/firebase_test_harness.dart';

/// Pumps [child] with a [StateUsers] provider and loaded localization.
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
  await tester.pump();
}

/// Builds a state populated with two selectable users.
StateUsers _populatedState() => StateUsers()
  ..data = [
    {'id': 'a', 'firstName': 'Ada', 'lastName': 'Byron'},
    {'id': 'b', 'firstName': 'Bob', 'lastName': 'Stone'},
  ];

void main() {
  group('UsersDropdown agent element', () {
    final index = AgentElementIndex.instance;

    setUp(() async {
      // Arrange: mock Firebase so StateUsers can touch FirebaseFirestore.
      await setupFirebaseForTest();
      index.reset();
    });
    tearDown(index.reset);

    testWidgets('should index the wrapped input under its automationKey', (
      WidgetTester tester,
    ) async {
      // Arrange
      final state = _populatedState();

      // Act
      await _pump(
        tester,
        state,
        const UsersDropdown(
          uid: 'a',
          automationKey: 'orders_form_dropdown_assignee',
          semanticHint: 'Person responsible for the order',
        ),
      );

      // Assert
      final snapshot = index.snapshotOf('orders_form_dropdown_assignee')!;
      expect(snapshot.type, AgentElementType.dropdown);
      expect(snapshot.hint, 'Person responsible for the order');
      expect(snapshot.value, 'a');
    });

    testWidgets('should let an agent select a user by id', (
      WidgetTester tester,
    ) async {
      // Arrange
      String? selected;
      final state = _populatedState();
      await _pump(
        tester,
        state,
        UsersDropdown(
          uid: 'a',
          automationKey: 'orders_form_dropdown_assignee',
          onChanged: (user) => selected = user.id,
        ),
      );

      // Act
      await index.handle('orders_form_dropdown_assignee')!.setter!('b');
      await tester.pump();

      // Assert
      expect(selected, 'b');
    });

    testWidgets('should remove the element when the dropdown is disposed', (
      WidgetTester tester,
    ) async {
      // Arrange
      final state = _populatedState();
      await _pump(
        tester,
        state,
        const UsersDropdown(
          uid: 'a',
          automationKey: 'orders_form_dropdown_assignee',
        ),
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // Assert
      expect(index.ids, isEmpty);
    });
  });
}
