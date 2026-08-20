import 'package:fabric_flutter/component/upload_image_media.dart';
import 'package:fabric_flutter/helper/app_localizations_delegate.dart';
import 'package:fabric_flutter/helper/media_helper.dart';
import 'package:fabric_flutter/serialized/media_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Localizations used so the three menu items render distinguishable labels.
///
/// The `label--upload-image-from-label` template carries a `{label}` placeholder
/// so each item resolves to a unique, human-readable string built from its
/// per-origin sub-label.
const Map<String, Map<String, String>> _locales = {
  'label--upload-image-from-label': {'en': 'Upload from {label}'},
  'label--upload-label': {'en': 'Upload {label}'},
  'label--gallery': {'en': 'Gallery'},
  'label--file': {'en': 'File'},
  'label--camera': {'en': 'Camera'},
  'label--image': {'en': 'Image'},
};

/// Pumps an [UploadImageMedia] with the test localizations loaded.
Future<void> pumpUploadImageMedia(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(locales: _locales),
      ],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(
        body: UploadImageMedia(
          path: 'account/account-1/media',
          callback: (String path, MediaData data) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('UploadImageMedia', () {
    group('image source menu', () {
      testWidgets(
        'should render gallery, files, and camera items in order with matching '
        'icons and labels',
        (tester) async {
          // Arrange
          await pumpUploadImageMedia(tester);
          expect(find.byType(PopupMenuButton<MediaOrigin>), findsOneWidget);

          // Act
          await tester.tap(find.byType(PopupMenuButton<MediaOrigin>));
          await tester.pumpAndSettle();

          // Assert: the three items render in the exact declared order.
          final values = tester
              .widgetList<PopupMenuItem<MediaOrigin>>(
                find.byType(PopupMenuItem<MediaOrigin>),
              )
              .map((item) => item.value)
              .toList();
          expect(values, <MediaOrigin>[
            MediaOrigin.gallery,
            MediaOrigin.files,
            MediaOrigin.camera,
          ]);

          // Assert: each item pairs the right value with the right icon and the
          // localized label built from `label--upload-image-from-label`.
          const expected = <(MediaOrigin, IconData, String)>[
            (MediaOrigin.gallery, Icons.image, 'Upload from Gallery'),
            (MediaOrigin.files, Icons.image_search, 'Upload from File'),
            (MediaOrigin.camera, Icons.photo_camera, 'Upload from Camera'),
          ];
          for (final (origin, icon, label) in expected) {
            final itemFinder = find.byWidgetPredicate(
              (widget) =>
                  widget is PopupMenuItem<MediaOrigin> &&
                  widget.value == origin,
            );
            expect(itemFinder, findsOneWidget);
            expect(
              find.descendant(of: itemFinder, matching: find.text(label)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: itemFinder, matching: find.byIcon(icon)),
              findsOneWidget,
            );
          }
        },
      );
    });
  });
}
