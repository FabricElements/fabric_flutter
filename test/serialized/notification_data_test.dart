import 'package:fabric_flutter/serialized/notification_data.dart';
import 'package:fabric_flutter/serialized/user_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationData', () {
    group('fromJson', () {
      test('should tolerate a null payload', () {
        // Arrange & Act
        final data = NotificationData.fromJson(null);

        // Assert
        expect(data, isA<NotificationData>());
        expect(data.clear, isFalse);
        expect(data.os, UserOS.unknown);
        expect(data.duration, 5);
      });

      test('should tolerate an empty map', () {
        // Arrange & Act
        final data = NotificationData.fromJson({});

        // Assert
        expect(data, isA<NotificationData>());
      });

      test('should deserialize all fields from a full payload', () {
        // Arrange
        final json = <String, dynamic>{
          'title': 'Hello',
          'body': 'You have a message.',
          'imageUrl': 'https://example.com/img.png',
          'type': 'alert',
          'path': '/notifications',
          'clear': true,
          'os': 'android',
          'typeString': 'ALERT',
          'duration': 10,
          'account': 'acct-1',
          'id': 'notif-001',
          'origin': 'fcm',
        };

        // Act
        final data = NotificationData.fromJson(json);

        // Assert
        expect(data.title, 'Hello');
        expect(data.body, 'You have a message.');
        expect(data.imageUrl, 'https://example.com/img.png');
        expect(data.type, 'alert');
        expect(data.path, '/notifications');
        expect(data.clear, isTrue);
        expect(data.os, UserOS.android);
        expect(data.typeString, 'ALERT');
        expect(data.duration, 10);
        expect(data.account, 'acct-1');
        expect(data.id, 'notif-001');
        expect(data.origin, 'fcm');
      });

      test(
        'should fall back to UserOS.unknown for an unrecognized os value',
        () {
          // Arrange
          final json = <String, dynamic>{'os': 'blackberry'};

          // Act — unknownEnumValue: UserOS.unknown is configured
          final data = NotificationData.fromJson(json);

          // Assert
          expect(data.os, UserOS.unknown);
        },
      );

      test('should deserialize each known UserOS variant', () {
        // Arrange
        const variants = <String, UserOS>{
          'android': UserOS.android,
          'ios': UserOS.ios,
          'macos': UserOS.macos,
          'linux': UserOS.linux,
          'web': UserOS.web,
          'windows': UserOS.windows,
          'unknown': UserOS.unknown,
        };

        for (final entry in variants.entries) {
          // Act
          final data = NotificationData.fromJson({'os': entry.key});

          // Assert
          expect(data.os, entry.value, reason: 'Failed for os=${entry.key}');
        }
      });

      test('should use default duration of 5 when not provided', () {
        // Arrange & Act
        final data = NotificationData.fromJson({'title': 'test'});

        // Assert
        expect(data.duration, 5);
      });

      test('should omit nullable optional fields when absent from JSON', () {
        // Arrange & Act
        final data = NotificationData.fromJson({});

        // Assert
        expect(data.title, isNull);
        expect(data.body, isNull);
        expect(data.imageUrl, isNull);
        expect(data.type, isNull);
        expect(data.path, isNull);
        expect(data.typeString, isNull);
        expect(data.account, isNull);
        expect(data.id, isNull);
        expect(data.origin, isNull);
      });
    });

    group('toJson', () {
      test('should serialize all non-null fields', () {
        // Arrange
        final data = NotificationData(
          title: 'T',
          body: 'B',
          type: 'info',
          path: '/home',
          clear: false,
          os: UserOS.ios,
          duration: 3,
          id: 'n-1',
        );

        // Act
        final json = data.toJson();

        // Assert
        expect(json['title'], 'T');
        expect(json['body'], 'B');
        expect(json['type'], 'info');
        expect(json['path'], '/home');
        expect(json['clear'], isFalse);
        expect(json['os'], 'ios');
        expect(json['duration'], 3);
        expect(json['id'], 'n-1');
      });

      test(
        'should omit account, id, and origin when null (includeIfNull: false)',
        () {
          // Arrange
          final data = NotificationData();

          // Act
          final json = data.toJson();

          // Assert
          expect(json.containsKey('account'), isFalse);
          expect(json.containsKey('id'), isFalse);
          expect(json.containsKey('origin'), isFalse);
        },
      );

      test('should include clear and os even when default values', () {
        // Arrange — clear and os have includeIfNull: true
        final data = NotificationData();

        // Act
        final json = data.toJson();

        // Assert
        expect(json.containsKey('clear'), isTrue);
        expect(json.containsKey('os'), isTrue);
        expect(json['clear'], isFalse);
        expect(json['os'], 'unknown');
      });

      test('should serialize os as its name string', () {
        // Arrange
        final data = NotificationData(os: UserOS.web);

        // Act
        final json = data.toJson();

        // Assert
        expect(json['os'], 'web');
      });
    });

    group('fromJson / toJson round-trip', () {
      test('should preserve all fields across a round-trip', () {
        // Arrange
        final original = NotificationData(
          title: 'Alert',
          body: 'Check this out.',
          type: 'promo',
          path: '/deals',
          clear: true,
          os: UserOS.macos,
          duration: 8,
          account: 'acct-99',
          id: 'n-99',
          origin: 'apns',
        );

        // Act
        final restored = NotificationData.fromJson(original.toJson());

        // Assert
        expect(restored.title, original.title);
        expect(restored.body, original.body);
        expect(restored.type, original.type);
        expect(restored.path, original.path);
        expect(restored.clear, original.clear);
        expect(restored.os, original.os);
        expect(restored.duration, original.duration);
        expect(restored.account, original.account);
        expect(restored.id, original.id);
        expect(restored.origin, original.origin);
      });
    });
  });
}
