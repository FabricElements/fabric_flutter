import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/component/update_password.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/serialized/password_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] with a loaded localization delegate so the staged field labels
/// and validation strings resolve to their bundled values.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Enters [text] into the [index]-th [InputData] field and settles the rebuild
/// so any newly revealed follow-up field is mounted before the next step.
Future<void> _enter(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(TextField).at(index), text);
  await tester.pumpAndSettle();
}

void main() {
  group('UpdatePassword', () {
    group('progressive reveal', () {
      testWidgets('should show only the current-password field initially', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, UpdatePassword(callback: (_) {}));

        // Assert
        expect(find.byType(InputData), findsOneWidget);
      });

      testWidgets('should reveal the new-password field after current entry', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, UpdatePassword(callback: (_) {}));
        await _enter(tester, 0, 'OldPass1!');

        // Assert
        expect(find.byType(InputData), findsNWidgets(2));
      });

      testWidgets('should reveal the repeat field for a valid new password', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, UpdatePassword(callback: (_) {}));
        await _enter(tester, 0, 'OldPass1!');
        await _enter(tester, 1, 'Str0ng!Pass');

        // Assert – current, new, and repeat fields are all visible.
        expect(find.byType(InputData), findsNWidgets(3));
      });
    });

    group('validation gating', () {
      testWidgets('should not show the submit button until fields match', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, UpdatePassword(callback: (_) {}));
        await _enter(tester, 0, 'OldPass1!');
        await _enter(tester, 1, 'Str0ng!Pass');
        await _enter(tester, 2, 'Different1!');

        // Assert
        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('should show the submit button once everything is valid', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, UpdatePassword(callback: (_) {}));
        await _enter(tester, 0, 'OldPass1!');
        await _enter(tester, 1, 'Str0ng!Pass');
        await _enter(tester, 2, 'Str0ng!Pass');

        // Assert
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('should reject a new password equal to the current one', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(tester, UpdatePassword(callback: (_) {}));
        await _enter(tester, 0, 'Str0ng!Pass');
        await _enter(tester, 1, 'Str0ng!Pass');

        // Assert – identical passwords never expose the submit button.
        expect(find.byType(FilledButton), findsNothing);
      });
    });

    group('confirmation', () {
      testWidgets('should defer the callback behind the warning dialog', (
        WidgetTester tester,
      ) async {
        // Arrange
        PasswordData? received;

        // Act
        await _pump(
          tester,
          UpdatePassword(callback: (data) => received = data),
        );
        await _enter(tester, 0, 'OldPass1!');
        await _enter(tester, 1, 'Str0ng!Pass');
        await _enter(tester, 2, 'Str0ng!Pass');
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // Assert – tapping submit opens the dialog but has not called back yet.
        expect(received, isNull);
      });
    });
  });
}
