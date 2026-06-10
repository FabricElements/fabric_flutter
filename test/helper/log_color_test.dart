import 'package:ansicolor/ansicolor.dart';
import 'package:fabric_flutter/helper/log_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogColor', () {
    setUp(() {
      // Arrange - force ANSI codes on so colored output is deterministic.
      ansiColorDisabled = false;
    });

    tearDown(() {
      ansiColorDisabled = true;
    });

    test('should expose an info pen that wraps text in ANSI codes', () {
      // Act
      final result = LogColor.info('info message');

      // Assert
      expect(LogColor.info, isA<AnsiPen>());
      expect(result, contains('info message'));
      expect(result, contains('\u001b['));
    });

    test('should expose a success pen that preserves the message', () {
      // Act
      final result = LogColor.success('done');

      // Assert
      expect(result, contains('done'));
    });

    test('should expose a warning pen that preserves the message', () {
      // Act
      final result = LogColor.warning('careful');

      // Assert
      expect(result, contains('careful'));
    });

    test('should expose an error pen that preserves the message', () {
      // Act
      final result = LogColor.error('boom');

      // Assert
      expect(result, contains('boom'));
    });
  });
}
