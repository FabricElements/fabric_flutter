import 'package:fabric_flutter/component/user_avatar.dart';
import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [UserAvatar] with [presence] under a seeded [brightness] theme.
Future<ColorScheme> _pump(
  WidgetTester tester,
  UserPresence presence,
  Brightness brightness,
) async {
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: UserAvatar(avatar: null, name: 'Ada', presence: presence),
          ),
        ),
      ),
    ),
  );
  return theme.colorScheme;
}

/// Returns the decoration of the 8dp presence badge.
BoxDecoration _badge(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((container) => container.decoration)
    .whereType<BoxDecoration>()
    .lastWhere(
      (decoration) =>
          decoration.shape == BoxShape.circle && decoration.border != null,
    );

void main() {
  group('UserAvatar', () {
    group('presence color roles', () {
      for (final brightness in Brightness.values) {
        testWidgets('should use primary for active in ${brightness.name}', (
          WidgetTester tester,
        ) async {
          // Arrange & Act
          final scheme = await _pump(tester, UserPresence.active, brightness);

          // Assert
          expect(_badge(tester).color, scheme.primary);
        });

        testWidgets('should use error for inactive in ${brightness.name}', (
          WidgetTester tester,
        ) async {
          // Arrange & Act
          final scheme = await _pump(tester, UserPresence.inactive, brightness);

          // Assert
          final badge = _badge(tester);
          expect(badge.color, scheme.error);
          expect((badge.border! as Border).top.color, scheme.surface);
        });
      }
    });
  });
}
