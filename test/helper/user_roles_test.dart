import 'package:fabric_flutter/helper/user_roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRoles.roleFromData', () {
    test('should default to "user" when no data is provided', () {
      // Arrange, Act
      final role = UserRoles.roleFromData();

      // Assert
      expect(role, 'user');
    });

    test('should use the provided role when compareData is null', () {
      // Arrange, Act
      final role = UserRoles.roleFromData(role: 'admin');

      // Assert
      expect(role, 'admin');
    });

    test('should prefer compareData role over the fallback role', () {
      // Arrange
      final compareData = <String, dynamic>{'role': 'editor'};

      // Act
      final role = UserRoles.roleFromData(
        compareData: compareData,
        role: 'admin',
      );

      // Assert
      expect(role, 'editor');
    });

    test('should return the default role when group is provided '
        'but compareData is null', () {
      // Arrange, Act
      final role = UserRoles.roleFromData(group: 'team-a', role: 'admin');

      // Assert
      expect(role, 'admin');
    });

    test('should prefix the role with the group when the group exists', () {
      // Arrange
      final compareData = <String, dynamic>{
        'role': 'user',
        'groups': {'team-a': 'manager'},
      };

      // Act
      final role = UserRoles.roleFromData(
        compareData: compareData,
        group: 'team-a',
      );

      // Assert
      expect(role, 'team-a-manager');
    });

    test('should return the base role without prefix when clean is true', () {
      // Arrange
      final compareData = <String, dynamic>{
        'role': 'user',
        'groups': {'team-a': 'manager'},
      };

      // Act
      final role = UserRoles.roleFromData(
        compareData: compareData,
        group: 'team-a',
        clean: true,
      );

      // Assert
      expect(role, 'manager');
    });

    test('should fall back to the default role when the group is missing '
        'from groups', () {
      // Arrange
      final compareData = <String, dynamic>{
        'role': 'editor',
        'groups': {'team-a': 'manager'},
      };

      // Act
      final role = UserRoles.roleFromData(
        compareData: compareData,
        group: 'team-b',
      );

      // Assert
      expect(role, 'editor');
    });
  });
}
