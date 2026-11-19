import 'dart:typed_data';

import 'package:fabric_flutter/helper/drop_file_format.dart';
import 'package:fabric_flutter/helper/media_file_converter_native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [DropZoneFile] with sensible defaults for converter tests.
DropZoneFile fileOf({
  String name = 'IMG_0001.heic',
  List<int> bytes = const [1, 2, 3, 4],
  String? mimeType,
}) => DropZoneFile(
  bytes: Uint8List.fromList(bytes),
  name: name,
  size: bytes.length,
  mimeType: mimeType,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaFileConverter.needsConversion', () {
    test('should require conversion for HEIC and HEIF names and types', () {
      // Arrange
      const cases = [
        (name: 'IMG_0001.heic', type: null),
        (name: 'IMG_0001.HEIC', type: null),
        (name: 'IMG_0001.heif', type: null),
        (name: 'IMG_0001.jpg', type: 'image/heic'),
        (name: 'IMG_0001.png', type: 'image/HEIF-Sequence'),
      ];

      // Act + Assert
      for (final entry in cases) {
        expect(
          MediaFileConverter.needsConversion(
            mimeType: entry.type,
            fileName: entry.name,
          ),
          isTrue,
          reason: '${entry.name} / ${entry.type} should need conversion',
        );
      }
    });

    test('should not require conversion for other files', () {
      // Arrange
      const cases = [
        (name: 'IMG_0001.jpg', type: 'image/jpeg'),
        (name: 'IMG_0001.png', type: 'image/png'),
        (name: 'notes.pdf', type: 'application/pdf'),
        (name: 'noextension', type: null),
      ];

      // Act + Assert
      for (final entry in cases) {
        expect(
          MediaFileConverter.needsConversion(
            mimeType: entry.type,
            fileName: entry.name,
          ),
          isFalse,
          reason: '${entry.name} / ${entry.type} should pass through',
        );
      }
    });
  });

  group('MediaFileConverterImpl', () {
    test(
      'should pass a file that needs no conversion through unchanged',
      () async {
        // Arrange
        const converter = MediaFileConverterImpl();
        final file = fileOf(name: 'photo.png', mimeType: 'image/png');

        // Act
        final result = await converter.convert(file);

        // Assert
        expect(result.file, same(file));
        expect(result.reason, isNull);
      },
    );

    test(
      'should report an undecodable HEIC as unsupported, not an error',
      () async {
        // Arrange
        const converter = MediaFileConverterImpl();
        // An `ftypheic` brand header with no image data: no platform decoder
        // can decode this payload, so the conversion must resolve — never
        // throw — and report the failure.
        final corrupt = List<int>.filled(64, 0);
        corrupt[4] = 0x66; // f
        corrupt[5] = 0x74; // t
        corrupt[6] = 0x79; // y
        corrupt[7] = 0x70; // p

        // Act
        final result = await converter.convert(
          fileOf(name: 'IMG_0001.heic', bytes: corrupt),
        );

        // Assert
        expect(result.file, isNull);
        expect(result.reason, isNotNull);
      },
    );

    test(
      'should resolve a HEIC to a rejection when the deadline expires',
      () async {
        // Arrange
        // A zero deadline expires before the decode completes, which
        // exercises the timeout path deterministically instead of waiting
        // the production duration.
        final converter = MediaFileConverterImpl(timeout: Duration.zero);

        // Act
        final result = await converter.convert(
          fileOf(name: 'IMG_0001.heic', bytes: const [1, 2, 3, 4]),
        );

        // Assert
        expect(result.file, isNull);
        expect(result.reason, isNotNull);
      },
    );
  });

  group('encodeRawPixelsAsJpeg', () {
    test('should re-encode raw RGBA pixels as a JPEG payload', () {
      // Arrange
      // A 2x1 fully-opaque red image: red, white.
      const width = 2, height = 1;
      final pixels = Uint8List.fromList([
        255, 0, 0, 255, //
        255, 255, 255, 255,
      ]);

      // Act
      final jpeg = encodeRawPixelsAsJpeg(
        RawPixelsJpegRequest(pixels, width, height),
      );

      // Assert
      expect(jpeg, isNotEmpty);
      // JPEG payloads begin with the SOI marker (FF D8) and end with EOI (FF D9).
      expect(jpeg[0], 0xFF);
      expect(jpeg[1], 0xD8);
      expect(jpeg[jpeg.length - 2], 0xFF);
      expect(jpeg[jpeg.length - 1], 0xD9);
    });
  });

  group('withJpegExtension', () {
    test('should replace the extension and keep the base name', () {
      // Act + Assert
      expect(withJpegExtension('IMG_0001.heic'), 'IMG_0001.jpg');
      expect(withJpegExtension('photo'), 'photo.jpg');
      expect(withJpegExtension('archive.tar.gz'), 'archive.tar.jpg');
    });
  });
}
