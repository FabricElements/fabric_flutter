import 'package:fabric_flutter/helper/density_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DensitySpacing', () {
    const standard = DensitySpacing(VisualDensity.standard);
    const comfortable = DensitySpacing(VisualDensity.comfortable);
    const compact = DensitySpacing(VisualDensity.compact);
    // No built-in "large" constant exists in Flutter, so a custom, more
    // spacious density (positive adjustment) covers that case.
    const large = DensitySpacing(VisualDensity(horizontal: 2, vertical: 3));

    group('horizontal', () {
      test('should not adjust value at standard density', () {
        // Arrange & Act
        final result = standard.horizontal(10);

        // Assert
        expect(result, 10);
      });

      test('should subtract half the horizontal adjustment at comfortable', () {
        // Arrange & Act
        final result = comfortable.horizontal(10);

        // Assert: baseSizeAdjustment.dx = -1 * 4 = -4, halved = -2.
        expect(result, 8);
      });

      test('should subtract half the horizontal adjustment at compact', () {
        // Arrange & Act
        final result = compact.horizontal(10);

        // Assert: baseSizeAdjustment.dx = -2 * 4 = -8, halved = -4.
        expect(result, 6);
      });

      test('should add half the horizontal adjustment at large density', () {
        // Arrange & Act
        final result = large.horizontal(10);

        // Assert: baseSizeAdjustment.dx = 2 * 4 = 8, halved = 4.
        expect(result, 14);
      });

      test('should clamp to min when the scaled value falls below it', () {
        // Arrange & Act
        final result = compact.horizontal(2, min: 4);

        // Assert: 2 - 4 = -2, which is below the floor of 4.
        expect(result, 4);
      });

      test('should not clamp when the scaled value is above min', () {
        // Arrange & Act
        final result = compact.horizontal(10, min: 4);

        // Assert: 10 - 4 = 6, which is above the floor of 4.
        expect(result, 6);
      });
    });

    group('vertical', () {
      test('should not adjust value at standard density', () {
        // Arrange & Act
        final result = standard.vertical(10);

        // Assert
        expect(result, 10);
      });

      test('should subtract half the vertical adjustment at comfortable', () {
        // Arrange & Act
        final result = comfortable.vertical(10);

        // Assert: baseSizeAdjustment.dy = -1 * 4 = -4, halved = -2.
        expect(result, 8);
      });

      test('should subtract half the vertical adjustment at compact', () {
        // Arrange & Act
        final result = compact.vertical(10);

        // Assert: baseSizeAdjustment.dy = -2 * 4 = -8, halved = -4.
        expect(result, 6);
      });

      test('should add half the vertical adjustment at large density', () {
        // Arrange & Act
        final result = large.vertical(10);

        // Assert: baseSizeAdjustment.dy = 3 * 4 = 12, halved = 6.
        expect(result, 16);
      });

      test('should clamp to min when the scaled value falls below it', () {
        // Arrange & Act
        final result = compact.vertical(2, min: 4);

        // Assert: 2 - 4 = -2, which is below the floor of 4.
        expect(result, 4);
      });

      test('should not clamp when the scaled value is above min', () {
        // Arrange & Act
        final result = compact.vertical(10, min: 4);

        // Assert: 10 - 4 = 6, which is above the floor of 4.
        expect(result, 6);
      });
    });

    group('gap', () {
      test('should not adjust value at standard density', () {
        // Arrange & Act
        final result = standard.gap(10);

        // Assert
        expect(result, 10);
      });

      test('should subtract the averaged adjustment at comfortable', () {
        // Arrange & Act
        final result = comfortable.gap(10);

        // Assert: (-4 + -4) / 4 = -2.
        expect(result, 8);
      });

      test('should subtract the averaged adjustment at compact', () {
        // Arrange & Act
        final result = compact.gap(10);

        // Assert: (-8 + -8) / 4 = -4.
        expect(result, 6);
      });

      test('should add the averaged adjustment at large density', () {
        // Arrange & Act
        final result = large.gap(10);

        // Assert: (8 + 12) / 4 = 5.
        expect(result, 15);
      });

      test('should clamp to min when the scaled value falls below it', () {
        // Arrange & Act
        final result = compact.gap(2, min: 4);

        // Assert: 2 - 4 = -2, which is below the floor of 4.
        expect(result, 4);
      });

      test('should not clamp when the scaled value is above min', () {
        // Arrange & Act
        final result = compact.gap(10, min: 4);

        // Assert: 10 - 4 = 6, which is above the floor of 4.
        expect(result, 6);
      });
    });

    group('appBarExtra', () {
      test('should return the min floor at compact density (the baseline)', () {
        // Arrange & Act
        final result = compact.appBarExtra();

        // Assert: compact.dy - compact.dy = 0, floored at the default min 0.
        expect(result, 0);
      });

      test('should return 0 extra at standard density beyond the floor', () {
        // Arrange & Act
        final result = standard.appBarExtra();

        // Assert: 0 - (-8) = 8.
        expect(result, 8);
      });

      test(
        'should return the difference from compact at comfortable density',
        () {
          // Arrange & Act
          final result = comfortable.appBarExtra();

          // Assert: -4 - (-8) = 4.
          expect(result, 4);
        },
      );

      test('should return the difference from compact at large density', () {
        // Arrange & Act
        final result = large.appBarExtra();

        // Assert: 12 - (-8) = 20.
        expect(result, 20);
      });

      test(
        'should clamp to min when supplied and larger than the computed value',
        () {
          // Arrange & Act
          final result = compact.appBarExtra(min: 5);

          // Assert: computed value is 0, below the floor of 5.
          expect(result, 5);
        },
      );
    });

    group('all', () {
      test(
        'should scale both axes from a single value at standard density',
        () {
          // Arrange & Act
          final result = standard.all(16);

          // Assert
          expect(
            result,
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          );
        },
      );

      test('should scale both axes from a single value at compact density', () {
        // Arrange & Act
        final result = compact.all(16);

        // Assert: each axis loses half of -8 = 4.
        expect(
          result,
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );
      });

      test('should apply the min floor to both axes', () {
        // Arrange & Act
        final result = compact.all(2, min: 4);

        // Assert: 2 - 4 = -2, floored to 4 on both axes.
        expect(result, const EdgeInsets.symmetric(horizontal: 4, vertical: 4));
      });
    });

    group('symmetric', () {
      test('should scale each axis independently at standard density', () {
        // Arrange & Act
        final result = standard.symmetric(horizontal: 12, vertical: 8);

        // Assert
        expect(result, const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
      });

      test('should scale each axis independently at comfortable density', () {
        // Arrange & Act
        final result = comfortable.symmetric(horizontal: 12, vertical: 8);

        // Assert: both axes lose half of -4 = 2.
        expect(result, const EdgeInsets.symmetric(horizontal: 10, vertical: 6));
      });

      test('should apply independent min floors per axis', () {
        // Arrange & Act
        final result = compact.symmetric(
          horizontal: 2,
          vertical: 2,
          minHorizontal: 3,
          minVertical: 5,
        );

        // Assert: 2 - 4 = -2, floored to 3 and 5 respectively.
        expect(result, const EdgeInsets.symmetric(horizontal: 3, vertical: 5));
      });

      test('should not clamp when values are above their min floors', () {
        // Arrange & Act
        final result = standard.symmetric(
          horizontal: 12,
          vertical: 8,
          minHorizontal: 1,
          minVertical: 1,
        );

        // Assert
        expect(result, const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
      });
    });

    group('only', () {
      test('should scale each side at standard density', () {
        // Arrange & Act
        final result = standard.only(left: 4, top: 8, right: 12, bottom: 16);

        // Assert
        expect(
          result,
          const EdgeInsets.only(left: 4, top: 8, right: 12, bottom: 16),
        );
      });

      test(
        'should scale horizontal and vertical sides independently at compact density',
        () {
          // Arrange & Act
          final result = compact.only(left: 8, top: 8, right: 8, bottom: 8);

          // Assert: horizontal sides lose 4, vertical sides lose 4.
          expect(
            result,
            const EdgeInsets.only(left: 4, top: 4, right: 4, bottom: 4),
          );
        },
      );

      test(
        'should apply independent min floors for horizontal and vertical sides',
        () {
          // Arrange & Act
          final result = compact.only(
            left: 1,
            top: 1,
            right: 1,
            bottom: 1,
            minHorizontal: 2,
            minVertical: 6,
          );

          // Assert: 1 - 4 = -3, floored to 2 (horizontal) and 6 (vertical).
          expect(
            result,
            const EdgeInsets.only(left: 2, top: 6, right: 2, bottom: 6),
          );
        },
      );
    });

    group('DensitySpacing.of', () {
      testWidgets('should read visualDensity from the ambient Theme', (
        tester,
      ) async {
        // Arrange
        DensitySpacing? density;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(visualDensity: VisualDensity.compact),
            home: Builder(
              builder: (context) {
                density = DensitySpacing.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // Act & Assert
        expect(density?.visualDensity, VisualDensity.compact);
        expect(density?.horizontal(10), 6);
      });

      testWidgets('should reflect a differently themed subtree', (
        tester,
      ) async {
        // Arrange
        DensitySpacing? density;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(visualDensity: VisualDensity.standard),
            home: Theme(
              data: ThemeData(visualDensity: VisualDensity.comfortable),
              child: Builder(
                builder: (context) {
                  density = DensitySpacing.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        // Act & Assert
        expect(density?.visualDensity, VisualDensity.comfortable);
      });
    });
  });
}
