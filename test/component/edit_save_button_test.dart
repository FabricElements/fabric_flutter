import 'package:fabric_flutter/component/alert_data.dart';
import 'package:fabric_flutter/component/edit_save_button.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] with a loaded localization delegate so button labels resolve.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('EditSaveButton', () {
    group('inactive state', () {
      testWidgets('should show only the edit action when inactive', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          EditSaveButton(cancel: () {}, save: () {}, edit: () {}),
        );

        // Assert
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.save), findsNothing);
        expect(find.byIcon(Icons.cancel), findsNothing);
      });

      testWidgets('should invoke edit when the edit action is tapped', (
        WidgetTester tester,
      ) async {
        // Arrange
        var edited = 0;

        // Act
        await _pump(
          tester,
          EditSaveButton(cancel: () {}, save: () {}, edit: () => edited++),
        );
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pump();

        // Assert
        expect(edited, 1);
      });
    });

    group('active state', () {
      testWidgets('should show save and cancel actions when active', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          EditSaveButton(active: true, cancel: () {}, save: () {}, edit: () {}),
        );

        // Assert
        expect(find.byIcon(Icons.save), findsOneWidget);
        expect(find.byIcon(Icons.cancel), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsNothing);
      });

      testWidgets('should invoke save immediately when confirm is false', (
        WidgetTester tester,
      ) async {
        // Arrange
        var saved = 0;

        // Act
        await _pump(
          tester,
          EditSaveButton(
            active: true,
            cancel: () {},
            save: () => saved++,
            edit: () {},
          ),
        );
        await tester.tap(find.byIcon(Icons.save));
        await tester.pump();

        // Assert
        expect(saved, 1);
      });

      testWidgets('should invoke cancel immediately when confirm is false', (
        WidgetTester tester,
      ) async {
        // Arrange
        var cancelled = 0;

        // Act
        await _pump(
          tester,
          EditSaveButton(
            active: true,
            cancel: () => cancelled++,
            save: () {},
            edit: () {},
          ),
        );
        await tester.tap(find.byIcon(Icons.cancel));
        await tester.pump();

        // Assert
        expect(cancelled, 1);
      });
    });

    group('confirm flow', () {
      testWidgets('should defer save behind a confirmation prompt', (
        WidgetTester tester,
      ) async {
        // Arrange
        var saved = 0;

        // Act
        await _pump(
          tester,
          EditSaveButton(
            active: true,
            confirm: true,
            alertWidget: AlertWidget.dialog,
            cancel: () {},
            save: () => saved++,
            edit: () {},
          ),
        );
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        // Assert – save is not called until the prompt is confirmed.
        expect(saved, 0);
      });
    });

    group('presentation', () {
      testWidgets('should render labeled buttons when labels is true', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          EditSaveButton(labels: true, cancel: () {}, save: () {}, edit: () {}),
        );

        // Assert
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('should lay actions out vertically when requested', (
        WidgetTester tester,
      ) async {
        // Arrange & Act
        await _pump(
          tester,
          EditSaveButton(
            active: true,
            direction: Axis.vertical,
            cancel: () {},
            save: () {},
            edit: () {},
          ),
        );

        // Assert
        final flex = tester.widget<Flex>(find.byType(Flex).last);
        expect(flex.direction, Axis.vertical);
      });
    });
  });
}
