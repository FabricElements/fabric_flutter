import 'package:fabric_flutter/component/managed_drop_zone.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/drop_file_format.dart';
import 'package:fabric_flutter/state/state_drop_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [ManagedDropZone] with the bundled localizations loaded.
Future<void> pumpDropZone(
  WidgetTester tester, {
  List<MediaDataUpload>? uploaded,
  List<DropFileFormat> formats = const [
    DropFileFormats.png,
    DropFileFormats.jpeg,
  ],
  bool expiry = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate(locales: {})],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(
        body: ManagedDropZone(
          path: 'account/account-1/media',
          expiry: expiry,
          formats: formats,
          callback: (media) => uploaded?.addAll(media),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ManagedDropZone', () {
    group('rendering', () {
      testWidgets('should render the drop prompt', (tester) async {
        // Arrange & Act
        await pumpDropZone(tester);

        // Assert
        expect(find.byType(ManagedDropZone), findsOneWidget);
        expect(find.byType(InkWell), findsWidgets);
      });

      testWidgets('should render an idle progress indicator', (tester) async {
        // Arrange & Act
        await pumpDropZone(tester);
        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );

        // Assert
        expect(indicator.value, 0);
      });

      testWidgets('should not list any media before a file is staged', (
        tester,
      ) async {
        // Arrange & Act
        await pumpDropZone(tester);

        // Assert
        expect(find.byIcon(Icons.delete), findsNothing);
      });

      testWidgets('should expose a tappable region for the file picker', (
        tester,
      ) async {
        // Arrange & Act
        await pumpDropZone(tester);
        final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);

        // Assert
        expect(inkWell.onTap, isNotNull);
      });
    });

    group('configuration', () {
      test('should retain the configured upload path', () {
        // Arrange & Act
        final widget = ManagedDropZone(
          path: 'account/account-1/media',
          expiry: true,
          formats: const [DropFileFormats.png],
          callback: (media) {},
        );

        // Assert
        expect(widget.path, 'account/account-1/media');
        expect(widget.expiry, isTrue);
      });

      test('should retain the supported formats', () {
        // Arrange & Act
        final widget = ManagedDropZone(
          path: 'account/account-1/media',
          expiry: false,
          formats: const [DropFileFormats.png, DropFileFormats.jpeg],
          callback: (media) {},
        );

        // Assert
        expect(widget.formats, hasLength(2));
      });
    });

    group('lifecycle', () {
      testWidgets('should dispose without leaving pending work', (
        tester,
      ) async {
        // Arrange
        await pumpDropZone(tester);

        // Act
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        // Assert
        expect(find.byType(ManagedDropZone), findsNothing);
      });
    });
  });
}
