import 'package:fabric_flutter/component/managed_drop_zone.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/drop_file_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [ManagedDropZone] with the bundled localizations loaded so the
/// semantic labels resolve to their English strings.
Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(
        body: ManagedDropZone(
          path: 'account/account-1/media',
          expiry: false,
          formats: const [DropFileFormats.png, DropFileFormats.jpeg],
          callback: (media) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ManagedDropZone', () {
    group('semantics', () {
      testWidgets('should announce the drop target as a labeled button', (
        tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await _pump(tester);

        // Assert
        final node = tester.getSemantics(
          find.bySemanticsLabel(
            'Drop files here or activate to browse for files',
          ),
        );
        expect(node.flagsCollection.isButton, isTrue);
        handle.dispose();
      });

      testWidgets('should offer a keyboard accessible browse alternative', (
        tester,
      ) async {
        // Arrange & Act
        await _pump(tester);

        // Assert
        expect(find.widgetWithText(TextButton, 'Browse files'), findsOneWidget);
      });

      testWidgets('should satisfy the tap target and labeling guidelines', (
        tester,
      ) async {
        // Arrange
        final handle = tester.ensureSemantics();

        // Act
        await _pump(tester);

        // Assert
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  });
}
