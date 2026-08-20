import 'package:fabric_flutter/helper/drop_file_format.dart';
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

void main() {
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

    test('should append a resolved extension to an extension-less name', () {
      // Arrange
      final state = StateDropZone(formats: dropZoneFormatsGeneral);

      // Act
      state.handleDroppedFile(dropped(name: 'photo', mimeType: 'image/png'));

      // Assert
      expect(state.mediaList.single.fileName, 'photo.png');
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
