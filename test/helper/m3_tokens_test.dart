import 'package:fabric_flutter/helper/m3_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M3Shape', () {
    test('should expose the M3 corner radius scale', () {
      // Arrange & Act
      const scale = [
        M3Shape.none,
        M3Shape.extraSmall,
        M3Shape.small,
        M3Shape.medium,
        M3Shape.large,
        M3Shape.extraLarge,
      ];

      // Assert
      expect(scale, [0, 4, 8, 12, 16, 28]);
    });

    test('should build a circular BorderRadius', () {
      // Arrange & Act
      final radius = M3Shape.circular(M3Shape.medium);

      // Assert
      expect(radius, BorderRadius.circular(12));
    });
  });

  group('M3Motion', () {
    Future<Duration?> resolveWith(
      WidgetTester tester, {
      required bool disableAnimations,
    }) async {
      Duration? result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              result = M3Motion.resolve(context, M3Motion.medium2);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('should keep the duration when motion is allowed', (
      tester,
    ) async {
      // Arrange & Act
      final result = await resolveWith(tester, disableAnimations: false);

      // Assert
      expect(result, const Duration(milliseconds: 300));
    });

    testWidgets('should return zero when reduced motion is requested', (
      tester,
    ) async {
      // Arrange & Act
      final result = await resolveWith(tester, disableAnimations: true);

      // Assert
      expect(result, Duration.zero);
    });

    testWidgets('should not reduce motion without a MediaQuery', (
      tester,
    ) async {
      // Arrange
      bool? result;
      bool? hasMediaQuery;

      // Act
      await tester.pumpWidget(
        View(
          view: tester.view,
          child: Builder(
            builder: (context) {
              hasMediaQuery = MediaQuery.maybeOf(context) != null;
              result = M3Motion.reduceMotion(context);
              return const SizedBox();
            },
          ),
        ),
        wrapWithView: false,
      );

      // Assert
      expect(hasMediaQuery, isTrue, reason: 'View supplies a MediaQuery');
      expect(result, isFalse);
    });
  });
}
