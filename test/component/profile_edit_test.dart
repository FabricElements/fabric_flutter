import 'package:fabric_flutter/component/profile_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAvatarPreview', () {
    test('should prefer staged local bytes with a byte-identity signature', () {
      // Arrange & Act
      final preview = resolveAvatarPreview(
        hasTemporalBytes: true,
        temporalBytesId: 4242,
        userImage: 'https://cdn.example.com/a.jpg',
        updatedSeconds: '100',
      );

      // Assert
      expect(preview.signature, 'mem:4242');
      expect(preview.url, isNull);
    });

    test('should build a cache-busted remote URL and signature', () {
      // Arrange & Act
      final preview = resolveAvatarPreview(
        hasTemporalBytes: false,
        userImage: 'https://cdn.example.com/a.jpg',
        updatedSeconds: '1700000000',
      );

      // Assert
      expect(
        preview.url,
        'https://cdn.example.com/a.jpg?size=medium&t=1700000000',
      );
      expect(preview.signature, 'net:https://cdn.example.com/a.jpg:1700000000');
    });

    test('should change the signature when the updated timestamp changes', () {
      // Arrange
      const image = 'https://cdn.example.com/a.jpg';

      // Act
      final first = resolveAvatarPreview(
        hasTemporalBytes: false,
        userImage: image,
        updatedSeconds: '1',
      );
      final second = resolveAvatarPreview(
        hasTemporalBytes: false,
        userImage: image,
        updatedSeconds: '2',
      );

      // Assert
      expect(first.signature, isNot(second.signature));
    });

    test('should tolerate a missing updated timestamp', () {
      // Arrange & Act
      final preview = resolveAvatarPreview(
        hasTemporalBytes: false,
        userImage: 'https://cdn.example.com/a.jpg',
      );

      // Assert
      expect(preview.url, 'https://cdn.example.com/a.jpg?size=medium&t=');
      expect(preview.signature, 'net:https://cdn.example.com/a.jpg:');
    });

    test('should fall back to a default signature when no source exists', () {
      // Arrange & Act
      final preview = resolveAvatarPreview(hasTemporalBytes: false);

      // Assert
      expect(preview.signature, 'default');
      expect(preview.url, isNull);
    });
  });
}
