import 'package:fabric_flutter/helper/drop_file_format.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DropFileFormat', () {
    group('matches', () {
      test('should match when the content type equals the MIME type', () {
        // Arrange
        const format = DropFileFormats.png;

        // Act
        final result = format.matches(
          contentType: 'image/png',
          fileName: 'no-extension',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should match case-insensitively on the content type', () {
        // Arrange
        const format = DropFileFormats.png;

        // Act
        final result = format.matches(contentType: 'IMAGE/PNG', fileName: 'x');

        // Assert
        expect(result, isTrue);
      });

      test('should fall back to the file extension when MIME is absent', () {
        // Arrange
        const format = DropFileFormats.jpeg;

        // Act
        final result = format.matches(fileName: 'photo.JPG');

        // Assert
        expect(result, isTrue);
      });

      test('should reject an unrelated content type and extension', () {
        // Arrange
        const format = DropFileFormats.pdf;

        // Act
        final result = format.matches(
          contentType: 'image/png',
          fileName: 'photo.png',
        );

        // Assert
        expect(result, isFalse);
      });

      test('should reject a name without a usable extension', () {
        // Arrange
        const format = DropFileFormats.csv;

        // Act
        final result = format.matches(fileName: 'contacts.');

        // Assert
        expect(result, isFalse);
      });

      test('should match vCard on its declared content type', () {
        // Arrange
        const format = DropFileFormats.vcard;

        // Act
        final result = format.matches(
          contentType: 'text/vcard',
          fileName: 'contacts',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should match vCard through its file extensions', () {
        // Arrange
        const format = DropFileFormats.vcard;

        // Act & Assert
        expect(format.matches(fileName: 'card.vcf'), isTrue);
        expect(format.matches(fileName: 'card.VCARD'), isTrue);
      });

      test('should match a vCard resolved as the x-variant content type', () {
        // Arrange
        // `lookupMimeType` maps the `vcf` extension to `text/x-vcard`, so the
        // equality check misses and the extension fallback must accept it.
        const format = DropFileFormats.vcard;

        // Act
        final result = format.matches(
          contentType: 'text/x-vcard',
          fileName: 'contacts.vcf',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should reject vCard with an unrelated content type and name', () {
        // Arrange
        const format = DropFileFormats.vcard;

        // Act
        final result = format.matches(
          contentType: 'text/csv',
          fileName: 'contacts.csv',
        );

        // Assert
        expect(result, isFalse);
      });
    });
  });

  group('extensionsForFormats', () {
    test('should deduplicate shared extensions preserving order', () {
      // Arrange
      const formats = [
        DropFileFormats.mp3,
        DropFileFormats.mpeg,
        DropFileFormats.jpeg,
      ];

      // Act
      final extensions = extensionsForFormats(formats);

      // Assert
      expect(extensions, ['mp3', 'mpeg', 'jpg', 'jpeg']);
    });

    test('should derive contact-list extensions from its preset', () {
      // Arrange & Act
      final extensions = extensionsForFormats(dropZoneFormatsContactList);

      // Assert
      expect(extensions, ['csv', 'xls', 'xlsx', 'vcf', 'vcard']);
    });
  });

  group('preset groups', () {
    test('should expose canonical const instances for identity checks', () {
      // Arrange & Act
      final first = dropZoneFormatsContactList.first;

      // Assert
      expect(identical(first, DropFileFormats.csv), isTrue);
    });

    test('should scope call-recording to audio formats only', () {
      // Arrange & Act
      final extensions = extensionsForFormats(dropZoneFormatsCallRecording);

      // Assert
      expect(extensions, ['mp3', 'wav']);
    });

    test('should include vCard only in the contact-list preset', () {
      // Arrange & Act
      final inContacts = dropZoneFormatsContactList.contains(
        DropFileFormats.vcard,
      );
      final inGeneral = dropZoneFormatsGeneral.contains(DropFileFormats.vcard);
      final inMessageTemplate = dropZoneFormatsMessageTemplate.contains(
        DropFileFormats.vcard,
      );

      // Assert
      expect(inContacts, isTrue);
      expect(inGeneral, isFalse);
      expect(inMessageTemplate, isFalse);
    });

    test('should accept HEIC and HEIF photos in the media presets', () {
      // Arrange & Act
      final general = dropZoneFormatsGeneral;
      final messageTemplate = dropZoneFormatsMessageTemplate;
      final byNameHeic = general
          .where((f) => f.matches(fileName: 'IMG_0001.heic'))
          .toList();
      final byTypeHeif = general
          .where((f) => f.matches(contentType: 'image/heif', fileName: 'x'))
          .toList();

      // Assert
      expect(
        general.contains(DropFileFormats.heic) &&
            general.contains(DropFileFormats.heif),
        isTrue,
      );
      expect(
        messageTemplate.contains(DropFileFormats.heic) &&
            messageTemplate.contains(DropFileFormats.heif),
        isTrue,
      );
      expect(byNameHeic, isNotEmpty);
      expect(byTypeHeif, isNotEmpty);
    });
  });

  group('DropZoneFile', () {
    test('should retain the bytes and metadata it is created with', () {
      // Arrange
      final bytes = Uint8List.fromList([1, 2, 3]);

      // Act
      final file = DropZoneFile(
        bytes: bytes,
        name: 'a.png',
        size: 3,
        mimeType: 'image/png',
      );

      // Assert
      expect(file.bytes, bytes);
      expect(file.name, 'a.png');
      expect(file.size, 3);
      expect(file.mimeType, 'image/png');
    });
  });
}
