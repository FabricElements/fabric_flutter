import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal app scaffolding required to pump a component.
Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Returns every non-null [Semantics] label rendered in the current tree.
Iterable<String> _labels(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((widget) => widget.properties.label)
    .whereType<String>();

void main() {
  group('UserAvatar', () {
    group('semantics', () {
      testWidgets('should derive an accessible name from the user name', (
        WidgetTester tester,
      ) async {
        // Arrange
        const name = 'Ada Lovelace';

        // Act
        await tester.pumpWidget(
          _app(const UserAvatar(avatar: null, name: name)),
        );

        // Assert
        expect(_labels(tester).any((label) => label.contains(name)), isTrue);
      });

      testWidgets('should prefer an explicit semanticsLabel', (
        WidgetTester tester,
      ) async {
        // Arrange
        const semanticsLabel = 'Profile photo of the account owner';

        // Act
        await tester.pumpWidget(
          _app(
            const UserAvatar(
              avatar: null,
              name: 'Ada Lovelace',
              semanticsLabel: semanticsLabel,
            ),
          ),
        );

        // Assert
        expect(
          _labels(tester).any((label) => label.contains(semanticsLabel)),
          isTrue,
        );
      });

      testWidgets('should expose the automationKey as a semantics identifier', (
        WidgetTester tester,
      ) async {
        // Arrange
        const automationKey = 'profile_header_image_avatar';

        // Act
        await tester.pumpWidget(
          _app(
            const UserAvatar(
              avatar: null,
              name: 'Ada Lovelace',
              automationKey: automationKey,
            ),
          ),
        );

        // Assert
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((widget) => widget.properties.identifier == automationKey),
          isTrue,
        );
      });

      testWidgets('should always expose a name when none is provided', (
        WidgetTester tester,
      ) async {
        // Arrange
        const avatar = UserAvatar(avatar: null);

        // Act
        await tester.pumpWidget(_app(avatar));

        // Assert
        expect(_labels(tester).where((label) => label.isNotEmpty), isNotEmpty);
      });
    });
  });
}
