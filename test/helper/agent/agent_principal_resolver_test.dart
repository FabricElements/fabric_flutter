import 'package:fabric_flutter/helper/agent/agent_principal_resolver.dart';
import 'package:fabric_flutter/serialized/agent_principal.dart';
import 'package:fabric_flutter/serialized/agent_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentPrincipalResolver', () {
    group('normalizeToken', () {
      test('should strip a bearer prefix and surrounding whitespace', () {
        // Arrange & Act
        final value = AgentPrincipalResolver.normalizeToken('  Bearer  abc  ');

        // Assert
        expect(value, 'abc');
      });

      test('should treat the scheme name case insensitively', () {
        // Arrange & Act
        final value = AgentPrincipalResolver.normalizeToken('bEaReR abc');

        // Assert
        expect(value, 'abc');
      });

      test('should return null for a null, empty, or blank token', () {
        // Arrange & Act & Assert
        expect(AgentPrincipalResolver.normalizeToken(null), isNull);
        expect(AgentPrincipalResolver.normalizeToken(''), isNull);
        expect(AgentPrincipalResolver.normalizeToken('   '), isNull);
        expect(AgentPrincipalResolver.normalizeToken('Bearer '), isNull);
      });
    });

    group('tokenFromRequest', () {
      test('should read the reserved auth parameter', () {
        // Arrange
        final request = AgentRequest(
          id: '1',
          method: 'invoke',
          params: <String, dynamic>{
            'auth': 'Bearer abc',
            'commandId': 'tap',
            'params': <String, dynamic>{'id': 'home_button'},
          },
        );

        // Act
        final token = AgentPrincipalResolver.tokenFromRequest(request);

        // Assert
        expect(token, 'abc');
      });

      test('should return null when the envelope carries no token', () {
        // Arrange
        final request = AgentRequest(id: '1', method: 'ping');

        // Act & Assert
        expect(AgentPrincipalResolver.tokenFromRequest(request), isNull);
      });

      test('should ignore a non-string auth parameter', () {
        // Arrange
        final request = AgentRequest(
          id: '1',
          method: 'ping',
          params: <String, dynamic>{'auth': 42},
        );

        // Act & Assert
        expect(AgentPrincipalResolver.tokenFromRequest(request), isNull);
      });
    });

    group('resolve', () {
      test('should return the principal produced by the verifier', () async {
        // Arrange
        final resolver = AgentPrincipalResolver(
          verifier: (token) => AgentPrincipal(id: 'user-$token'),
        );

        // Act
        final principal = await resolver.resolve('Bearer abc');

        // Assert
        expect(principal?.id, 'user-abc');
      });

      test('should not call the verifier for a missing token', () async {
        // Arrange
        var calls = 0;
        final resolver = AgentPrincipalResolver(
          verifier: (token) {
            calls++;
            return AgentPrincipal(id: 'user');
          },
        );

        // Act
        final principal = await resolver.resolve(null);

        // Assert
        expect(principal, isNull);
        expect(calls, 0);
      });

      test('should verify a token only once while cached', () async {
        // Arrange
        var calls = 0;
        final resolver = AgentPrincipalResolver(
          verifier: (token) {
            calls++;
            return AgentPrincipal(id: 'user-1');
          },
        );

        // Act
        await resolver.resolve('abc');
        await resolver.resolve('abc');
        await resolver.resolve('Bearer abc');

        // Assert
        expect(calls, 1);
      });

      test('should re-verify once the cache lifetime elapses', () async {
        // Arrange
        var calls = 0;
        final resolver = AgentPrincipalResolver(
          verifier: (token) {
            calls++;
            return AgentPrincipal(id: 'user-1');
          },
          cacheTtl: Duration.zero,
        );

        // Act
        await resolver.resolve('abc');
        await resolver.resolve('abc');

        // Assert
        expect(calls, 2);
      });

      test('should not cache a rejected token', () async {
        // Arrange
        var calls = 0;
        final resolver = AgentPrincipalResolver(
          verifier: (token) {
            calls++;
            return null;
          },
        );

        // Act
        final first = await resolver.resolve('abc');
        final second = await resolver.resolve('abc');

        // Assert
        expect(first, isNull);
        expect(second, isNull);
        expect(calls, 2);
      });

      test('should reject an already expired principal', () async {
        // Arrange
        final resolver = AgentPrincipalResolver(
          verifier: (token) => AgentPrincipal(
            id: 'user-1',
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        );

        // Act
        final principal = await resolver.resolve('abc');

        // Assert
        expect(principal, isNull);
      });

      test('should treat a throwing verifier as a denial', () async {
        // Arrange
        final resolver = AgentPrincipalResolver(
          verifier: (token) => throw StateError('backend down'),
        );

        // Act
        final principal = await resolver.resolve('abc');

        // Assert
        expect(principal, isNull);
      });

      test('should evict the least recently used entry', () async {
        // Arrange
        var calls = 0;
        final resolver = AgentPrincipalResolver(
          verifier: (token) {
            calls++;
            return AgentPrincipal(id: 'user-$token');
          },
          maxCacheEntries: 1,
        );

        // Act
        await resolver.resolve('a');
        await resolver.resolve('b');
        await resolver.resolve('a');

        // Assert
        expect(calls, 3);
      });
    });

    group('invalidate', () {
      test('should force re-verification of a single token', () async {
        // Arrange
        var calls = 0;
        final resolver = AgentPrincipalResolver(
          verifier: (token) {
            calls++;
            return AgentPrincipal(id: 'user-1');
          },
        );
        await resolver.resolve('abc');

        // Act
        resolver.invalidate('abc');
        await resolver.resolve('abc');

        // Assert
        expect(calls, 2);
      });

      test('should clear the whole cache when no token is supplied', () async {
        // Arrange
        var calls = 0;
        final resolver = AgentPrincipalResolver(
          verifier: (token) {
            calls++;
            return AgentPrincipal(id: 'user-$token');
          },
        );
        await resolver.resolve('a');
        await resolver.resolve('b');

        // Act
        resolver.invalidate();
        await resolver.resolve('a');
        await resolver.resolve('b');

        // Assert
        expect(calls, 4);
      });
    });
  });
}
