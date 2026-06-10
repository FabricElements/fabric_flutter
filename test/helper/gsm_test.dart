import 'package:fabric_flutter/helper/gsm.dart';
import 'package:fabric_flutter/serialized/gsm_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GSM.isUnicode', () {
    test('should return false for plain GSM 7-bit text', () {
      // Arrange, Act & Assert
      expect(GSM.isUnicode('Hello World'), isFalse);
    });

    test('should return true when text contains a non-GSM character', () {
      // Arrange, Act & Assert
      expect(GSM.isUnicode('Hello 😀'), isTrue);
    });
  });

  group('GSM.getTotalLengthGSM', () {
    test('should count standard characters as a single unit each', () {
      // Arrange, Act & Assert
      expect(GSM.getTotalLengthGSM('abc'), 3);
    });

    test('should count extension-table characters as two units', () {
      // Arrange - the Euro sign is part of the GSM extension table.
      // Act & Assert
      expect(GSM.getTotalLengthGSM('€'), 2);
    });
  });

  group('GSM.info', () {
    test('should return an empty payload for null content', () {
      // Arrange, Act
      final data = GSM.info(null);

      // Assert
      expect(data.text, '');
      expect(data.segments, 0);
      expect(data.charsLeft, 160);
      expect(data.charSet, CharSet.gsm);
      expect(data.parts, isEmpty);
    });

    test('should return an empty payload for empty content', () {
      // Arrange, Act
      final data = GSM.info('');

      // Assert
      expect(data.segments, 0);
      expect(data.charSet, CharSet.gsm);
    });

    test('should treat a short GSM message as a single segment', () {
      // Arrange, Act
      final data = GSM.info('Hello');

      // Assert
      expect(data.charSet, CharSet.gsm);
      expect(data.segments, 1);
      expect(data.charsLeft, 160 - 5);
      expect(data.parts, ['Hello']);
    });

    test('should split a long GSM message into multiple 153-char segments', () {
      // Arrange - 200 GSM characters exceeds the single-segment limit of 160.
      final content = 'a' * 200;

      // Act
      final data = GSM.info(content);

      // Assert
      expect(data.charSet, CharSet.gsm);
      expect(data.segments, 2);
      expect(data.parts.first.length, 153);
      expect(data.parts.last.length, 47);
    });

    test(
      'should treat a short unicode message as a single 70-char segment',
      () {
        // Arrange, Act
        final data = GSM.info('Hi 😀');

        // Assert
        expect(data.charSet, CharSet.unicode);
        expect(data.segments, 1);
        expect(data.charsLeft, 70 - 'Hi 😀'.length);
      },
    );

    test('should split a long unicode message into 67-char segments', () {
      // Arrange - 80 chars including an emoji forces unicode multi-part.
      final content = '😀${'a' * 79}';

      // Act
      final data = GSM.info(content);

      // Assert
      expect(data.charSet, CharSet.unicode);
      expect(data.segments, greaterThan(1));
      expect(data.parts.first.length, 67);
    });
  });

  group('GSM.toGSM', () {
    test('should return an empty string for null content', () {
      // Arrange, Act & Assert
      expect(GSM.toGSM(null), '');
    });

    test('should collapse multiple spaces into a single space', () {
      // Arrange, Act & Assert
      expect(GSM.toGSM('a    b'), 'a b');
    });

    test('should trim leading and trailing whitespace', () {
      // Arrange, Act & Assert
      expect(GSM.toGSM('   hello   '), 'hello');
    });

    test('should normalize three or more line breaks into exactly two', () {
      // Arrange, Act
      final result = GSM.toGSM('a\n\n\n\nb');

      // Assert
      expect(result, 'a\n\nb');
    });
  });
}
