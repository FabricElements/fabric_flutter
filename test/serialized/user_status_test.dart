import 'package:fabric_flutter/serialized/user_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomVisualDensity', () {
    test('should have expected enum values', () {
      // Arrange & Act
      const values = CustomVisualDensity.values;

      // Assert
      expect(values, contains(CustomVisualDensity.adaptive));
      expect(values, contains(CustomVisualDensity.compact));
      expect(values, contains(CustomVisualDensity.comfortable));
      expect(values, contains(CustomVisualDensity.standard));
      expect(values, contains(CustomVisualDensity.large));
    });
  });

  group('UserStatus', () {
    group('fromJson', () {
      test('should tolerate a null payload and use defaults', () {
        // Arrange & Act
        final data = UserStatus.fromJson(null);

        // Assert
        expect(data, isA<UserStatus>());
        expect(data.signedIn, isFalse);
        expect(data.admin, isFalse);
        expect(data.role, 'user');
        expect(data.language, 'en');
        expect(data.theme, ThemeMode.light);
        expect(data.visualDensity, CustomVisualDensity.adaptive);
        expect(data.ready, isFalse);
      });

      test('should tolerate an empty map and use defaults', () {
        // Arrange & Act
        final data = UserStatus.fromJson({});

        // Assert
        expect(data, isA<UserStatus>());
        expect(data.role, 'user');
      });

      test('should deserialize all fields from a full payload', () {
        // Arrange
        final json = <String, dynamic>{
          'signedIn': true,
          'admin': true,
          'role': 'editor',
          'uid': 'user-abc',
          'language': 'es',
          'theme': 'dark',
          'visualDensity': 'compact',
          'ready': true,
        };

        // Act
        final data = UserStatus.fromJson(json);

        // Assert
        expect(data.signedIn, isTrue);
        expect(data.admin, isTrue);
        expect(data.role, 'editor');
        expect(data.uid, 'user-abc');
        expect(data.language, 'es');
        expect(data.theme, ThemeMode.dark);
        expect(data.visualDensity, CustomVisualDensity.compact);
        expect(data.ready, isTrue);
      });

      test(
        'should fall back to ThemeMode.light for an unknown theme value',
        () {
          // Arrange
          final json = <String, dynamic>{'theme': 'neon'};

          // Act — unknownEnumValue: ThemeMode.light is configured
          final data = UserStatus.fromJson(json);

          // Assert
          expect(data.theme, ThemeMode.light);
        },
      );

      test(
        'should fall back to CustomVisualDensity.adaptive for an unknown visualDensity value',
        () {
          // Arrange
          final json = <String, dynamic>{'visualDensity': 'ultra'};

          // Act — unknownEnumValue: CustomVisualDensity.adaptive is configured
          final data = UserStatus.fromJson(json);

          // Assert
          expect(data.visualDensity, CustomVisualDensity.adaptive);
        },
      );

      test('should deserialize ThemeMode.system from JSON', () {
        // Arrange
        final json = <String, dynamic>{'theme': 'system'};

        // Act
        final data = UserStatus.fromJson(json);

        // Assert
        expect(data.theme, ThemeMode.system);
      });

      test('should deserialize each CustomVisualDensity variant', () {
        // Arrange
        const variants = <String, CustomVisualDensity>{
          'adaptive': CustomVisualDensity.adaptive,
          'compact': CustomVisualDensity.compact,
          'comfortable': CustomVisualDensity.comfortable,
          'standard': CustomVisualDensity.standard,
          'large': CustomVisualDensity.large,
        };

        for (final entry in variants.entries) {
          // Act
          final data = UserStatus.fromJson({'visualDensity': entry.key});

          // Assert
          expect(
            data.visualDensity,
            entry.value,
            reason: 'Failed for visualDensity=${entry.key}',
          );
        }
      });
    });

    group('toJson', () {
      test('should serialize basic fields', () {
        // Arrange
        final data = UserStatus(
          signedIn: true,
          admin: false,
          role: 'viewer',
          language: 'en',
        );

        // Act
        final json = data.toJson();

        // Assert
        expect(json['signedIn'], isTrue);
        expect(json['admin'], isFalse);
        expect(json['role'], 'viewer');
        expect(json['language'], 'en');
      });

      test('should serialize theme as its name string', () {
        // Arrange
        final data = UserStatus(theme: ThemeMode.dark);

        // Act
        final json = data.toJson();

        // Assert
        expect(json['theme'], 'dark');
      });

      test('should serialize visualDensity as its name string', () {
        // Arrange
        final data = UserStatus(visualDensity: CustomVisualDensity.compact);

        // Act
        final json = data.toJson();

        // Assert
        expect(json['visualDensity'], 'compact');
      });

      test('should omit uid when null (includeIfNull: false)', () {
        // Arrange
        final data = UserStatus();

        // Act
        final json = data.toJson();

        // Assert
        expect(json.containsKey('uid'), isFalse);
      });

      test('should include uid when set', () {
        // Arrange
        final data = UserStatus(uid: 'uid-xyz');

        // Act
        final json = data.toJson();

        // Assert
        expect(json['uid'], 'uid-xyz');
      });
    });

    group('fromJson / toJson round-trip', () {
      test('should preserve all fields across a round-trip', () {
        // Arrange
        final original = UserStatus(
          signedIn: true,
          admin: true,
          role: 'manager',
          uid: 'u-1',
          language: 'es',
          theme: ThemeMode.system,
          visualDensity: CustomVisualDensity.comfortable,
          ready: true,
        );

        // Act
        final restored = UserStatus.fromJson(original.toJson());

        // Assert
        expect(restored.signedIn, original.signedIn);
        expect(restored.admin, original.admin);
        expect(restored.role, original.role);
        expect(restored.uid, original.uid);
        expect(restored.language, original.language);
        expect(restored.theme, original.theme);
        expect(restored.visualDensity, original.visualDensity);
        expect(restored.ready, original.ready);
      });
    });
  });
}
