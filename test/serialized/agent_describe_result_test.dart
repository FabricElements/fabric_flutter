import 'package:fabric_flutter/serialized/agent_command_info.dart';
import 'package:fabric_flutter/serialized/agent_describe_result.dart';
import 'package:fabric_flutter/serialized/agent_route_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentDescribeResult', () {
    group('fromJson', () {
      test('should deserialize nested routes and commands', () {
        // Arrange
        final json = <String, dynamic>{
          'app': 'Furcata',
          'version': '1.0.0',
          'routes': [
            {'name': '/dashboard'},
          ],
          'commands': [
            {'id': 'navigate', 'title': 'Navigate'},
          ],
        };

        // Act
        final result = AgentDescribeResult.fromJson(json);

        // Assert
        expect(result.app, 'Furcata');
        expect(result.version, '1.0.0');
        expect(result.routes.single.name, '/dashboard');
        expect(result.commands.single.id, 'navigate');
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final result = AgentDescribeResult.fromJson(null);

        // Assert
        expect(result.app, '');
        expect(result.version, '');
        expect(result.routes, isEmpty);
        expect(result.commands, isEmpty);
      });
    });

    group('toJson', () {
      test('should round-trip without losing data', () {
        // Arrange
        final result = AgentDescribeResult(
          app: 'Furcata',
          version: '2.0.0',
          routes: [AgentRouteInfo(name: '/orders')],
          commands: [AgentCommandInfo(id: 'tap', title: 'Tap')],
        );

        // Act
        final restored = AgentDescribeResult.fromJson(
          AgentDescribeResult.fromJson(result.toJson()).toJson(),
        );

        // Assert
        expect(restored.version, '2.0.0');
        expect(restored.routes.single.name, '/orders');
        expect(restored.commands.single.id, 'tap');
      });
    });
  });
}
