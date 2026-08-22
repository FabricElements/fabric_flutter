import 'package:fabric_flutter/helper/url_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlSafety', () {
    group('safeUri', () {
      test('should accept an https URL', () {
        // Arrange & Act
        final uri = UrlSafety.safeUri('https://example.com/path?q=1');

        // Assert
        expect(uri, isNotNull);
        expect(uri!.scheme, 'https');
        expect(uri.host, 'example.com');
      });

      test('should accept an http URL', () {
        // Arrange & Act
        final uri = UrlSafety.safeUri('http://example.com');

        // Assert
        expect(uri, isNotNull);
      });

      test('should trim surrounding whitespace', () {
        // Arrange & Act
        final uri = UrlSafety.safeUri('  https://example.com  ');

        // Assert
        expect(uri?.host, 'example.com');
      });

      test('should reject a javascript URL', () {
        // Arrange & Act & Assert
        expect(UrlSafety.safeUri('javascript:alert(1)'), isNull);
      });

      test('should reject a javascript URL with an absolute path', () {
        // Arrange & Act & Assert: this form defeats a `hasAbsolutePath` check.
        expect(UrlSafety.safeUri('javascript:/a'), isNull);
      });

      test('should reject a data URL', () {
        // Arrange & Act & Assert
        expect(
          UrlSafety.safeUri('data:text/html,<script>alert(1)</script>'),
          isNull,
        );
      });

      test('should reject a file URL', () {
        // Arrange & Act & Assert: `Uri.tryParse` succeeds here and reports an
        // absolute path, so parsing alone validates nothing.
        expect(UrlSafety.safeUri('file:///etc/passwd'), isNull);
      });

      test('should reject a scheme-relative or bare value', () {
        // Arrange & Act & Assert
        expect(UrlSafety.safeUri('example.com/path'), isNull);
        expect(UrlSafety.safeUri('/relative/path'), isNull);
      });

      test('should reject an https URL without a host', () {
        // Arrange & Act & Assert
        expect(UrlSafety.safeUri('https:///nohost'), isNull);
      });

      test('should reject null and empty values', () {
        // Arrange & Act & Assert
        expect(UrlSafety.safeUri(null), isNull);
        expect(UrlSafety.safeUri(''), isNull);
        expect(UrlSafety.safeUri('   '), isNull);
      });

      test('should accept an uppercase scheme', () {
        // Arrange & Act: `Uri` normalizes the scheme, but the guard must not
        // depend on the caller having done so.
        final uri = UrlSafety.safeUri('HTTPS://example.com');

        // Assert
        expect(uri, isNotNull);
      });
    });

    group('isSafe', () {
      test('should agree with safeUri for an allowed scheme', () {
        // Arrange & Act & Assert: positive control for the rejections below.
        expect(UrlSafety.isSafe('https://example.com'), isTrue);
      });

      test('should reject every scheme outside the allow list', () {
        // Arrange
        const candidates = <String>[
          'javascript:alert(1)',
          'data:text/plain,hi',
          'file:///etc/passwd',
          'mailto:someone@example.com',
          'tel:+15555550100',
          'intent://scan/#Intent;scheme=zxing;end',
        ];

        // Act & Assert
        for (final candidate in candidates) {
          expect(
            UrlSafety.isSafe(candidate),
            isFalse,
            reason: '$candidate must not be launchable',
          );
        }
      });
    });

    group('allowedSchemes', () {
      test('should permit only http and https', () {
        // Arrange & Act & Assert
        expect(UrlSafety.allowedSchemes, {'https', 'http'});
      });
    });
  });
}
