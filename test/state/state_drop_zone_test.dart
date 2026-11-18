import 'package:fabric_flutter/helper/drop_file_format.dart';
import 'package:fabric_flutter/helper/media_file_converter.dart';
import 'package:fabric_flutter/state/state_drop_zone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [MediaDataUpload] with sensible defaults for testing dedup logic.
MediaDataUpload media({
  String fileName = 'file.png',
  List<int> bytes = const [65, 65, 65, 65],
  int size = 4,
  String contentType = 'image/png',
}) => MediaDataUpload(
  bytes: Uint8List.fromList(bytes),
  fileName: fileName,
  extension: 'png',
  contentType: contentType,
  size: size,
);

/// Builds a [DropZoneFile] with sensible defaults for testing drop handling.
DropZoneFile dropped({
  String name = 'file.png',
  List<int> bytes = const [65, 65, 65, 65],
  String? mimeType = 'image/png',
}) => DropZoneFile(
  bytes: Uint8List.fromList(bytes),
  name: name,
  size: bytes.length,
  mimeType: mimeType,
);

/// A converter double that stages a fixed replacement for converted files.
class _FakeConverter extends MediaFileConverter {
  /// Creates a double that either converts everything or converts nothing.
  const _FakeConverter({required this.supported});

  /// Whether the double reports conversions as supported.
  final bool supported;

  @override
  Future<MediaConversionResult> convert(DropZoneFile file) async {
    if (!MediaFileConverter.needsConversion(
      mimeType: file.mimeType,
      fileName: file.name,
    )) {
      return MediaConversionResult(file: file);
    }
    if (!supported) {
      return const MediaConversionResult.unsupported('conversion-unsupported');
    }
    final bytes = Uint8List.fromList(const [1, 2, 3, 4]);
    return MediaConversionResult(
      file: DropZoneFile(
        bytes: bytes,
        name: 'IMG_0001.jpg',
        size: bytes.lengthInBytes,
        mimeType: 'image/jpeg',
      ),
    );
  }
}

void main() {
  // Conversion rejections resolve an alert context through the global
  // navigator key, which reads the widget binding even outside a widget tree.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StateDropZone.addMediaIfNew', () {
    test('should add a new media item and notify listeners', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      var notified = 0;
      state.addListener(() => notified++);

      // Act
      final added = state.addMediaIfNew(media());

      // Assert
      expect(added, isTrue);
      expect(state.mediaList.length, 1);
      expect(notified, 1);
    });

    test('should ignore an exact duplicate without notifying', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.addMediaIfNew(media());
      var notified = 0;
      state.addListener(() => notified++);

      // Act
      final added = state.addMediaIfNew(media());

      // Assert
      expect(added, isFalse);
      expect(state.mediaList.length, 1);
      expect(notified, 0);
    });

    test('should add an item that differs only by bytes', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.addMediaIfNew(media(bytes: const [65, 65, 65, 65]));

      // Act
      final added = state.addMediaIfNew(media(bytes: const [66, 66, 66, 66]));

      // Assert
      expect(added, isTrue);
      expect(state.mediaList.length, 2);
    });

    test('should add an item that differs only by file name', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.addMediaIfNew(media(fileName: 'a.png'));

      // Act
      final added = state.addMediaIfNew(media(fileName: 'b.png'));

      // Assert
      expect(added, isTrue);
      expect(state.mediaList.length, 2);
    });
  });

  group('StateDropZone.handleDroppedFile', () {
    test('should stage a file whose format is accepted', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);

      // Act
      final staged = state.handleDroppedFile(dropped(name: 'photo.png'));

      // Assert
      expect(staged, isTrue);
      expect(state.mediaList.single.fileName, 'photo.png');
    });

    test('should reject a file whose format is not accepted', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsCallRecording);

      // Act
      final staged = state.handleDroppedFile(
        dropped(name: 'photo.png', mimeType: 'image/png'),
      );

      // Assert
      expect(staged, isFalse);
      expect(state.mediaList, isEmpty);
    });

    test('should classify a HEIC photo by name when MIME is missing', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);
      const heicBytes = [0, 0, 0, 24, 102, 116, 121, 112, 104, 101, 105, 99];

      // Act
      final staged = state.handleDroppedFile(
        dropped(name: 'IMG_0001.heic', bytes: heicBytes, mimeType: null),
      );

      // Assert
      expect(staged, isTrue);
      expect(state.mediaList.single.fileName, 'IMG_0001.heic');
      expect(state.mediaList.single.contentType, 'image/heic');
    });

    test('should resolve the content type from bytes when MIME is missing', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0, 0, 0, 0,
      ]);

      // Act
      final staged = state.handleDroppedFile(
        DropZoneFile(bytes: png, name: 'photo.png', size: png.length),
      );

      // Assert
      expect(staged, isTrue);
      expect(state.mediaList.single.contentType, 'image/png');
    });

    test('should stage a vCard file dropped on the contact-list preset', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsContactList);

      // Act
      final staged = state.handleDroppedFile(
        dropped(name: 'contacts.vcf', mimeType: null),
      );

      // Assert
      expect(staged, isTrue);
      expect(state.mediaList.single.fileName, 'contacts.vcf');
      expect(state.mediaList.single.contentType, 'text/x-vcard');
    });

    test('should append a resolved extension to an extension-less name', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);

      // Act
      state.handleDroppedFile(dropped(name: 'photo', mimeType: 'image/png'));

      // Assert
      expect(state.mediaList.single.fileName, 'photo.png');
    });

    test(
      'should stage an unresolved-MIME file whose extension is accepted',
      () {
        // Arrange
        final state = StateDropZone(formats: dropZoneFormatsGeneral);

        // Act
        final staged = state.handleDroppedFile(
          dropped(name: 'photo.png', mimeType: null),
        );

        // Assert
        expect(staged, isTrue);
        expect(state.mediaList.single.fileName, 'photo.png');
        expect(state.mediaList.single.contentType, 'image/png');
      },
    );

    test('should borrow the accepted format MIME when sniffing fails', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);

      // Act
      final staged = state.handleDroppedFile(
        dropped(name: 'clip.mov', mimeType: null),
      );

      // Assert
      expect(staged, isTrue);
      expect(state.mediaList.single.contentType, 'video/quicktime');
    });

    test('should still stage a CSV file that carries no MIME type', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsContactList);

      // Act
      final staged = state.handleDroppedFile(
        dropped(name: 'contacts.csv', mimeType: null),
      );

      // Assert
      expect(staged, isTrue);
      expect(state.mediaList.single.fileName, 'contacts.csv');
      expect(state.mediaList.single.contentType, 'text/csv');
    });

    test(
      'should reject an unresolved-MIME file whose extension is not accepted',
      () {
        // Arrange
        final state = StateDropZone(formats: dropZoneFormatsCallRecording);

        // Act
        final staged = state.handleDroppedFile(
          dropped(name: 'photo.png', mimeType: null),
        );

        // Assert
        expect(staged, isFalse);
        expect(state.mediaList, isEmpty);
      },
    );

    test('should reject an unresolved-MIME file with an unknown extension', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);

      // Act
      final staged = state.handleDroppedFile(
        dropped(name: 'weird.zyx', mimeType: null),
      );

      // Assert
      expect(staged, isFalse);
      expect(state.mediaList, isEmpty);
    });
  });

  group('StateDropZone.onDroppedFiles', () {
    test('should stage only the accepted files from a mixed drop', () async {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsCallRecording);

      // Act
      await state.onDroppedFiles([
        dropped(name: 'clip.mp3', mimeType: 'audio/mpeg'),
        dropped(name: 'photo.png', mimeType: 'image/png'),
      ]);

      // Assert
      expect(state.mediaList.length, 1);
      expect(state.mediaList.single.fileName, 'clip.mp3');
      expect(state.loading, isFalse);
    });
  });

  group('StateDropZone conversion pipeline', () {
    test(
      'should stage a HEIC file as JPEG when the converter converts it',
      () async {
        // Arrange
        final state = StateDropZone(
          formats: dropZoneFormatsGeneral,
          converter: const _FakeConverter(supported: true),
        );
        const heicBytes = [0, 0, 0, 24, 102, 116, 121, 112, 104, 101, 105, 99];

        // Act
        await state.onDroppedFiles([
          dropped(name: 'IMG_0001.heic', bytes: heicBytes, mimeType: null),
        ]);

        // Assert
        expect(state.mediaList.single.fileName, 'IMG_0001.jpg');
        expect(state.mediaList.single.contentType, 'image/jpeg');
        expect(state.loading, isFalse);
      },
    );

    test(
      'should not stage a HEIC file when the converter cannot convert it',
      () async {
        // Arrange
        final state = StateDropZone(
          formats: dropZoneFormatsGeneral,
          converter: const _FakeConverter(supported: false),
        );
        const heicBytes = [0, 0, 0, 24, 102, 116, 121, 112, 104, 101, 105, 99];

        // Act
        await state.onDroppedFiles([
          dropped(name: 'IMG_0001.heic', bytes: heicBytes, mimeType: null),
        ]);

        // Assert
        expect(state.mediaList, isEmpty);
        expect(state.loading, isFalse);
      },
    );

    test(
      'should pass files that need no conversion through unchanged',
      () async {
        // Arrange
        final state = StateDropZone(
          formats: dropZoneFormatsGeneral,
          converter: const _FakeConverter(supported: true),
        );
        const pngBytes = [65, 65, 65, 65];

        // Act
        await state.onDroppedFiles([
          dropped(name: 'photo.png', bytes: pngBytes, mimeType: 'image/png'),
        ]);

        // Assert
        expect(state.mediaList.single.fileName, 'photo.png');
        expect(state.mediaList.single.contentType, 'image/png');
        expect(state.mediaList.single.size, pngBytes.length);
      },
    );

    test('should reject a HEIC drop on the default native converter', () async {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);
      const heicBytes = [0, 0, 0, 24, 102, 116, 121, 112, 104, 101, 105, 99];

      // Act
      await state.onDroppedFiles([
        dropped(name: 'IMG_0001.heic', bytes: heicBytes, mimeType: null),
      ]);

      // Assert
      expect(state.mediaList, isEmpty);
      expect(state.loading, isFalse);
    });

    test('should keep staging later files after one is rejected', () async {
      // Arrange
      final state = StateDropZone(
        formats: dropZoneFormatsGeneral,
        converter: const _FakeConverter(supported: false),
      );
      const heicBytes = [0, 0, 0, 24, 102, 116, 121, 112, 104, 101, 105, 99];

      // Act
      await state.onDroppedFiles([
        dropped(name: 'IMG_0001.heic', bytes: heicBytes, mimeType: null),
        dropped(name: 'photo.png', mimeType: 'image/png'),
      ]);

      // Assert
      expect(state.mediaList.single.fileName, 'photo.png');
      expect(state.loading, isFalse);
    });
  });

  group('StateDropZone.updateDragging', () {
    test('should toggle the dragging flag and notify once per change', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      var notified = 0;
      state.addListener(() => notified++);

      // Act
      state.updateDragging(true);
      state.updateDragging(true);
      state.updateDragging(false);

      // Assert
      expect(notified, 2);
      expect(state.dragging, isFalse);
    });
  });

  group('StateDropZone.clear helpers', () {
    test('should remove only successfully uploaded media', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.addMediaIfNew(media(fileName: 'a.png'));
      state.addMediaIfNew(media(fileName: 'b.png'));
      state.mediaList.first.status = MediaDataUploadStatus.uploaded;

      // Act
      state.clearSuccessfullyUploaded();

      // Assert
      expect(state.mediaList.length, 1);
      expect(state.mediaList.single.fileName, 'b.png');
    });

    test('should remove a single item by index', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.addMediaIfNew(media(fileName: 'a.png'));
      state.addMediaIfNew(media(fileName: 'b.png'));

      // Act
      state.removeMedia(0);

      // Assert
      expect(state.mediaList.single.fileName, 'b.png');
    });

    test('should clear every staged item', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.addMediaIfNew(media(fileName: 'a.png'));
      state.addMediaIfNew(media(fileName: 'b.png'));

      // Act
      state.clearAll();

      // Assert
      expect(state.mediaList, isEmpty);
    });
  });

  group('StateDropZone.dispose', () {
    test('should report itself as disposed after dispose', () {
      // Arrange
      final state = StateDropZone(formats: const []);

      // Act
      state.dispose();

      // Assert
      expect(state.disposed, isTrue);
    });

    test('should not be disposed before dispose is called', () {
      // Arrange & Act
      final state = StateDropZone(formats: const []);

      // Assert
      expect(state.disposed, isFalse);
    });

    test('should release the pending selection on dispose', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.addMediaIfNew(media());

      // Act
      state.dispose();

      // Assert
      expect(state.mediaList, isEmpty);
    });

    test('should not throw when a late callback notifies after dispose', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.dispose();

      // Act & Assert
      expect(state.refresh, returnsNormally);
    });

    test('should not notify listeners after dispose', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      var notified = 0;
      state.addListener(() => notified++);
      state.dispose();

      // Act
      state.refresh();

      // Assert
      expect(notified, 0);
    });

    test('should reject new media after dispose', () {
      // Arrange
      final state = StateDropZone(formats: const []);
      state.dispose();

      // Act
      final added = state.addMediaIfNew(media());

      // Assert
      expect(added, isFalse);
      expect(state.mediaList, isEmpty);
    });

    test('should reject dropped files after dispose', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);
      state.dispose();

      // Act
      final staged = state.handleDroppedFile(dropped());

      // Assert
      expect(staged, isFalse);
      expect(state.mediaList, isEmpty);
    });
  });
}
