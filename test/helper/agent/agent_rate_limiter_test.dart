import 'package:fabric_flutter/helper/agent/agent_rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentRateLimiter', () {
    group('allow', () {
      test('should permit requests up to the limit', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 3);

        // Act
        final results = [
          limiter.allow('a'),
          limiter.allow('a'),
          limiter.allow('a'),
        ];

        // Assert
        expect(results, [true, true, true]);
      });

      test('should reject once the limit is exhausted', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 2);

        // Act
        limiter.allow('a');
        limiter.allow('a');
        final rejected = limiter.allow('a');

        // Assert
        expect(rejected, isFalse);
      });

      test('should bucket callers independently', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 1);

        // Act
        final first = limiter.allow('a');
        final second = limiter.allow('b');
        final third = limiter.allow('a');

        // Assert
        expect(first, isTrue);
        expect(second, isTrue);
        expect(third, isFalse);
      });

      test('should forget requests older than the window', () async {
        // Arrange
        final limiter = AgentRateLimiter(
          maxRequests: 1,
          window: const Duration(milliseconds: 20),
        );

        // Act
        final first = limiter.allow('a');
        final blocked = limiter.allow('a');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final recovered = limiter.allow('a');

        // Assert
        expect(first, isTrue);
        expect(blocked, isFalse);
        expect(recovered, isTrue);
      });

      test('should evict the least recently used key', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 1, maxKeys: 1);

        // Act
        limiter.allow('a');
        limiter.allow('b');

        // Assert
        expect(limiter.remaining('a'), 1);
        expect(limiter.remaining('b'), 0);
      });
    });

    group('remaining', () {
      test('should report the full budget for an unseen key', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 5);

        // Act & Assert
        expect(limiter.remaining('a'), 5);
      });

      test('should never report a negative budget', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 1);

        // Act
        limiter.allow('a');
        limiter.allow('a');

        // Assert
        expect(limiter.remaining('a'), 0);
      });
    });

    group('reset', () {
      test('should clear a single key', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 1);
        limiter.allow('a');

        // Act
        limiter.reset('a');

        // Assert
        expect(limiter.allow('a'), isTrue);
      });

      test('should clear every key when none is supplied', () {
        // Arrange
        final limiter = AgentRateLimiter(maxRequests: 1);
        limiter.allow('a');
        limiter.allow('b');

        // Act
        limiter.reset();

        // Assert
        expect(limiter.allow('a'), isTrue);
        expect(limiter.allow('b'), isTrue);
      });
    });
  });
}
