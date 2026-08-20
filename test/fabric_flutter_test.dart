import 'package:fabric_flutter/fabric_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('package:fabric_flutter/fabric_flutter.dart', () {
    test('should expose RegexHelper without a deep path import', () {
      // Arrange, Act & Assert
      expect(RegexHelper.email.hasMatch('user@example.com'), isTrue);
      expect(RegexHelper.slug.hasMatch('my-slug'), isTrue);
    });

    test('should expose helpers and state containers from one entrypoint', () {
      // Arrange, Act & Assert
      expect(InputValidation.isEmailValid('user@example.com'), isTrue);
      expect(FormatData, isNotNull);
      expect(StateViewAuth(), isA<StateViewAuth>());
    });
  });
}
