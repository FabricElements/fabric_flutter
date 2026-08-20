import 'package:fabric_flutter/helper/agent/agent_command.dart';
import 'package:fabric_flutter/helper/agent/agent_principal_resolver.dart';
import 'package:fabric_flutter/helper/agent/agent_token_authorizer.dart';
import 'package:fabric_flutter/serialized/agent_error.dart';
import 'package:fabric_flutter/serialized/agent_principal.dart';
import 'package:fabric_flutter/serialized/agent_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a resolver that accepts `good` and rejects everything else.
AgentPrincipalResolver _resolver({
  String role = 'user',
  Map<String, String> groups = const {},
}) => AgentPrincipalResolver(
  verifier: (token) => token == 'good'
      ? AgentPrincipal(id: 'user-1', role: role, groups: groups)
      : null,
);

/// Builds a request carrying [token] in the reserved `auth` parameter.
AgentRequest _request(
  String method, {
  String? token,
  Map<String, dynamic>? params,
}) => AgentRequest(
  id: '1',
  method: method,
  params: <String, dynamic>{...?params, 'auth': ?token},
);

/// Builds a command that requires [role].
AgentCommand _command(String? role) => AgentCommand.define(
  id: 'archive_order',
  title: 'Archive order',
  requiresRole: role,
  handler: (context) => true,
);

void main() {
  group('AgentTokenAuthorizer', () {
    group('authenticate', () {
      test('should deny a request with no token', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(principals: _resolver());

        // Act
        final decision = await authorizer.authorize(
          _request('invoke'),
          command: _command(null),
        );

        // Assert
        expect(decision.allowed, isFalse);
        expect(decision.code, AgentErrorCode.unauthorized);
        expect(decision.message, contains('bearer token'));
      });

      test('should deny a request with an invalid token', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(principals: _resolver());

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'bad'),
          command: _command(null),
        );

        // Assert
        expect(decision.allowed, isFalse);
        expect(decision.code, AgentErrorCode.unauthorized);
      });

      test('should allow a request with a valid token', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(principals: _resolver());

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'Bearer good'),
          command: _command(null),
        );

        // Assert
        expect(decision.allowed, isTrue);
      });

      test('should forward the resolved principal through meta', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(
          principals: _resolver(role: 'editor', groups: {'acme': 'admin'}),
        );

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command(null),
        );

        // Assert
        expect(decision.meta[AgentTokenAuthorizer.metaPrincipalId], 'user-1');
        expect(decision.meta[AgentTokenAuthorizer.metaRole], 'editor');
        expect(decision.meta[AgentTokenAuthorizer.metaGroups], {
          'acme': 'admin',
        });
        expect(
          decision.meta[AgentTokenAuthorizer.metaPrincipal],
          isA<Map<String, dynamic>>(),
        );
      });
    });

    group('discovery', () {
      test('should gate ping and describe by default', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(principals: _resolver());

        // Act
        final ping = await authorizer.authorize(_request('ping'));
        final describe = await authorizer.authorize(_request('describe'));

        // Assert
        expect(ping.allowed, isFalse);
        expect(describe.allowed, isFalse);
      });

      test('should allow anonymous discovery when opted in', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(
          principals: _resolver(),
          requireAuthenticationForDiscovery: false,
        );

        // Act
        final ping = await authorizer.authorize(_request('ping'));
        final state = await authorizer.authorize(_request('state'));

        // Assert
        expect(ping.allowed, isTrue);
        expect(state.allowed, isFalse);
      });

      test('should still gate invoke when discovery is open', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(
          principals: _resolver(),
          requireAuthenticationForDiscovery: false,
          requireAuthenticationForState: false,
        );

        // Act
        final decision = await authorizer.authorize(
          _request('invoke'),
          command: _command(null),
        );

        // Assert
        expect(decision.allowed, isFalse);
      });
    });

    group('roles', () {
      test('should deny a principal without the required role', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(principals: _resolver());

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command('editor'),
        );

        // Assert
        expect(decision.allowed, isFalse);
        expect(decision.code, AgentErrorCode.unauthorized);
        expect(decision.message, contains('editor'));
      });

      test('should allow an exact role match', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(
          principals: _resolver(role: 'editor'),
        );

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command('editor'),
        );

        // Assert
        expect(decision.allowed, isTrue);
      });

      test('should allow the admin super role for any command', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(
          principals: _resolver(role: 'admin'),
        );

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command('editor'),
        );

        // Assert
        expect(decision.allowed, isTrue);
      });

      test('should resolve a group scoped requirement', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(
          principals: _resolver(groups: {'acme': 'editor'}),
        );

        // Act
        final scoped = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command('acme-editor'),
        );
        final other = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command('other-editor'),
        );

        // Assert
        expect(scoped.allowed, isTrue);
        expect(other.allowed, isFalse);
      });

      test('should honor a host supplied role check', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(
          principals: _resolver(role: 'nobody'),
          roleCheck: (principal, requiredRole) => true,
        );

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command('editor'),
        );

        // Assert
        expect(decision.allowed, isTrue);
      });

      test('should ignore an empty role requirement', () async {
        // Arrange
        final authorizer = AgentTokenAuthorizer(principals: _resolver());

        // Act
        final decision = await authorizer.authorize(
          _request('invoke', token: 'good'),
          command: _command(''),
        );

        // Assert
        expect(decision.allowed, isTrue);
      });
    });

    group('defaultRoleCheck', () {
      test('should match a role held in any group', () {
        // Arrange
        final principal = AgentPrincipal(
          id: 'user-1',
          groups: const {'acme': 'editor'},
        );

        // Act & Assert
        expect(
          AgentTokenAuthorizer.defaultRoleCheck(principal, 'editor'),
          isTrue,
        );
        expect(
          AgentTokenAuthorizer.defaultRoleCheck(principal, 'owner'),
          isFalse,
        );
      });

      test('should let a group admin satisfy a group requirement', () {
        // Arrange
        final principal = AgentPrincipal(
          id: 'user-1',
          groups: const {'acme': 'admin'},
        );

        // Act & Assert
        expect(
          AgentTokenAuthorizer.defaultRoleCheck(principal, 'acme-editor'),
          isTrue,
        );
      });
    });
  });
}
