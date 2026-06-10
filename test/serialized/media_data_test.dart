import 'package:fabric_flutter/serialized/media_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaData', () {
    Map<String, dynamic> buildJson() => <String, dynamic>{
      'data': 'base64data',
      'contentType': 'image/png',
      'extension': 'png',
      'fileName': 'avatar.png',
      'size': 2048,
      'width': 100,
      'height': 200,
    };

    group('fromJson', () {
      test('should deserialize all fields including dimensions', () {
        // Arrange
        final json = buildJson();

        // Act
        final media = MediaData.fromJson(json);

        // Assert
        expect(media.data, 'base64data');
        expect(media.contentType, 'image/png');
        expect(media.extension, 'png');
        expect(media.fileName, 'avatar.png');
        expect(media.size, 2048);
        expect(media.width, 100);
        expect(media.height, 200);
      });

      test('should allow null width and height for non-visual media', () {
        // Arrange
        final json = buildJson()
          ..remove('width')
          ..remove('height');

        // Act
        final media = MediaData.fromJson(json);

        // Assert
        expect(media.width, isNull);
        expect(media.height, isNull);
      });
    });

    group('toJson', () {
      test('should serialize every field back to a map', () {
        // Arrange
        final media = MediaData(
          data: 'abc',
          contentType: 'text/plain',
          extension: 'txt',
          fileName: 'notes.txt',
          size: 12,
        );

        // Act
        final json = media.toJson();

        // Assert
        expect(json['data'], 'abc');
        expect(json['contentType'], 'text/plain');
        expect(json['extension'], 'txt');
        expect(json['fileName'], 'notes.txt');
        expect(json['size'], 12);
        expect(json['width'], isNull);
        expect(json['height'], isNull);
      });

      test('should round-trip through fromJson', () {
        // Arrange
        final original = MediaData.fromJson(buildJson());

        // Act
        final restored = MediaData.fromJson(original.toJson());

        // Assert
        expect(restored.fileName, original.fileName);
        expect(restored.size, original.size);
        expect(restored.width, original.width);
        expect(restored.height, original.height);
      });
    });
  });
}
