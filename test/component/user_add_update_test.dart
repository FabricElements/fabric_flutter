import 'package:fabric_flutter/component/user_add_update.dart';
import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

UserAddUpdate _sample() => UserAddUpdate(
  name: true,
  onConfirm: (UserData data, {String? group}) async {},
  onChanged: () async {},
);

void main() {
  group('UserAddUpdate', () {
    testWidgets('should render the form without throwing', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_wrap(_sample()));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
    });

    testWidgets('should reuse a single scroll controller across rebuilds', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(_sample()));
      await tester.pumpAndSettle();
      final first = tester.widget<Scrollbar>(find.byType(Scrollbar)).controller;

      // Act — trigger a rebuild
      await tester.pumpWidget(_wrap(_sample()));
      await tester.pumpAndSettle();
      final second = tester
          .widget<Scrollbar>(find.byType(Scrollbar))
          .controller;

      // Assert — the same controller instance survives the rebuild
      expect(identical(first, second), isTrue);
    });

    testWidgets('should dispose cleanly when removed from the tree', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_wrap(_sample()));
      await tester.pumpAndSettle();

      // Act — replacing the widget triggers State.dispose
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
    });
  });
}
