import 'package:fabric_flutter/serialized/agent_route_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentRouteInfo', () {
    group('fromJson', () {
      test('should deserialize every field', () {
        // Arrange
        final json = <String, dynamic>{
          'name': '/dashboard',
          'title': 'Dashboard',
          'description': 'Main overview',
          'requiresRole': 'admin',
        };

        // Act
        final route = AgentRouteInfo.fromJson(json);

        // Assert
        expect(route.name, '/dashboard');
        expect(route.title, 'Dashboard');
        expect(route.description, 'Main overview');
        expect(route.requiresRole, 'admin');
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final route = AgentRouteInfo.fromJson(null);

        // Assert
        expect(route.name, '');
        expect(route.title, isNull);
        expect(route.requiresRole, isNull);
      });
    });

    group('toJson', () {
      test('should round-trip without losing data', () {
        // Arrange
        final route = AgentRouteInfo(name: '/orders', title: 'Orders');

        // Act
        final restored = AgentRouteInfo.fromJson(
          AgentRouteInfo.fromJson(route.toJson()).toJson(),
        );

        // Assert
        expect(restored.name, '/orders');
        expect(restored.title, 'Orders');
      });
    });
  });
}
