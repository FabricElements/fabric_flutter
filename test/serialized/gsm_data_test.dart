import 'package:fabric_flutter/serialized/gsm_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GSMData', () {
    group('constructor', () {
      test('should derive chars from the text length', () {
        // Arrange & Act
        final data = GSMData(
          text: 'hello',
          segments: 1,
          charsLeft: 155,
          charSet: CharSet.gsm,
          parts: const ['hello'],
        );

        // Assert
        expect(data.chars, 5);
        expect(data.text, 'hello');
        expect(data.segments, 1);
        expect(data.charsLeft, 155);
        expect(data.charSet, CharSet.gsm);
        expect(data.parts, ['hello']);
      });

      test('should report zero chars for an empty message', () {
        // Arrange & Act
        final data = GSMData(
          text: '',
          segments: 0,
          charsLeft: 160,
          charSet: CharSet.gsm,
          parts: const [],
        );

        // Assert
        expect(data.chars, 0);
      });
    });

    group('fromJson', () {
      test('should deserialize a complete unicode payload', () {
        // Arrange
        final json = <String, dynamic>{
          'text': 'café',
          'segments': 2,
          'charsLeft': 60,
          'charSet': 'unicode',
          'parts': ['ca', 'fé'],
        };

        // Act
        final data = GSMData.fromJson(json);

        // Assert
        expect(data.charSet, CharSet.unicode);
        expect(data.segments, 2);
        expect(data.parts, ['ca', 'fé']);
        expect(data.chars, 'café'.length);
      });
    });

    group('toJson', () {
      test('should serialize all stored fields including derived chars', () {
        // Arrange
        final data = GSMData(
          text: 'abc',
          segments: 1,
          charsLeft: 157,
          charSet: CharSet.gsm,
          parts: const ['abc'],
        );

        // Act
        final json = data.toJson();

        // Assert
        expect(json['text'], 'abc');
        expect(json['segments'], 1);
        expect(json['charsLeft'], 157);
        expect(json['charSet'], 'gsm');
        expect(json['parts'], ['abc']);
      });

      test('should round-trip through fromJson without losing data', () {
        // Arrange
        final original = GSMData(
          text: 'round trip',
          segments: 1,
          charsLeft: 150,
          charSet: CharSet.gsm,
          parts: const ['round trip'],
        );

        // Act
        final restored = GSMData.fromJson(original.toJson());

        // Assert
        expect(restored.text, original.text);
        expect(restored.segments, original.segments);
        expect(restored.charSet, original.charSet);
        expect(restored.parts, original.parts);
      });
    });
  });
}
