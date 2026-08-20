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
      expect(extensions, ['csv', 'xls', 'xlsx']);
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
