import 'package:fabric_flutter/serialized/agent_principal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentPrincipal', () {
    group('fromJson', () {
      test('should deserialize identifier, role, and groups', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'user-1',
          'role': 'admin',
          'groups': <String, dynamic>{'acme': 'editor'},
          'scopes': <dynamic>['agent'],
        };

        // Act
        final principal = AgentPrincipal.fromJson(json);

        // Assert
        expect(principal.id, 'user-1');
        expect(principal.role, 'admin');
        expect(principal.groups['acme'], 'editor');
        expect(principal.scopes, ['agent']);
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final principal = AgentPrincipal.fromJson(null);

        // Assert
        expect(principal.id, '');
        expect(principal.role, 'user');
        expect(principal.groups, isEmpty);
        expect(principal.scopes, isEmpty);
        expect(principal.expiresAt, isNull);
      });

      test('should tolerate an empty payload', () {
        // Arrange & Act
        final principal = AgentPrincipal.fromJson(<String, dynamic>{});

        // Assert
        expect(principal, isA<AgentPrincipal>());
        expect(principal.isExpired, isFalse);
      });
    });

    group('toJson', () {
      test('should round-trip through JSON unchanged', () {
        // Arrange
        final expiry = DateTime.utc(2030, 1, 1);
        final original = AgentPrincipal(
          id: 'user-2',
          role: 'editor',
          groups: const {'acme': 'admin'},
          scopes: const ['agent', 'read'],
          expiresAt: expiry,
          claims: const {'email': 'redacted'},
        );

        // Act
        final restored = AgentPrincipal.fromJson(
          AgentPrincipal.fromJson(original.toJson()).toJson(),
        );

        // Assert
        expect(restored.id, 'user-2');
        expect(restored.role, 'editor');
        expect(restored.groups, {'acme': 'admin'});
        expect(restored.scopes, ['agent', 'read']);
        expect(restored.expiresAt, expiry);
        expect(restored.claims, {'email': 'redacted'});
      });
    });

    group('isExpired', () {
      test('should report false when no expiry is published', () {
        // Arrange
        final principal = AgentPrincipal(id: 'user-3');

        // Act & Assert
        expect(principal.isExpired, isFalse);
      });

      test('should report true for a past expiry', () {
        // Arrange
        final principal = AgentPrincipal(
          id: 'user-4',
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        );

        // Act & Assert
        expect(principal.isExpired, isTrue);
      });

      test('should report false for a future expiry', () {
        // Arrange
        final principal = AgentPrincipal(
          id: 'user-5',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );

        // Act & Assert
        expect(principal.isExpired, isFalse);
      });
    });

    group('roleInGroup', () {
      test('should return the role held inside a group', () {
        // Arrange
        final principal = AgentPrincipal(
          id: 'user-6',
          groups: const {'acme': 'editor'},
        );

        // Act & Assert
        expect(principal.roleInGroup('acme'), 'editor');
        expect(principal.roleInGroup('other'), isNull);
      });
    });
  });
}
