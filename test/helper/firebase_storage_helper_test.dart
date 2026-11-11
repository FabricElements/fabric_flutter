import 'package:fabric_flutter/helper/firebase_storage_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseStorageHelper.uploadMetadata', () {
    test('should leave custom metadata unset when none is supplied', () {
      // Arrange / Act
      final metadata = FirebaseStorageHelper.uploadMetadata(
        contentType: 'image/png',
      );

      // Assert
      expect(metadata.contentType, 'image/png');
      expect(metadata.contentDisposition, isNull);
      expect(metadata.customMetadata, isNull);
    });

    test('should preserve the content type and dispose file name', () {
      // Arrange / Act
      final metadata = FirebaseStorageHelper.uploadMetadata(
        contentType: 'video/mp4',
        fileName: 'clip.mp4',
      );

      // Assert
      expect(metadata.contentType, 'video/mp4');
      expect(metadata.contentDisposition, 'inline; filename="clip.mp4"');
      expect(metadata.customMetadata, isNull);
    });

    test('should attach the supplied custom metadata', () {
      // Arrange
      const customMetadata = {'type': 'whatsapp'};

      // Act
      final metadata = FirebaseStorageHelper.uploadMetadata(
        contentType: 'image/jpeg',
        customMetadata: customMetadata,
      );

      // Assert
      expect(metadata.customMetadata, customMetadata);
    });

    test('should keep custom metadata alongside the download behaviour', () {
      // Arrange / Act
      final metadata = FirebaseStorageHelper.uploadMetadata(
        contentType: 'application/pdf',
        fileName: 'brief.pdf',
        customMetadata: const {'type': 'whatsapp'},
      );

      // Assert
      expect(metadata.contentType, 'application/pdf');
      expect(metadata.contentDisposition, 'inline; filename="brief.pdf"');
      expect(metadata.customMetadata, {'type': 'whatsapp'});
    });
  });
}
