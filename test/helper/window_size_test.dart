import 'package:fabric_flutter/helper/window_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowSizeClass', () {
    group('fromWidth', () {
      test('should map each breakpoint boundary to its class', () {
        // Arrange
        final cases = <double, WindowSizeClass>{
          0: WindowSizeClass.compact,
          599.9: WindowSizeClass.compact,
          600: WindowSizeClass.medium,
          839.9: WindowSizeClass.medium,
          840: WindowSizeClass.expanded,
          1199.9: WindowSizeClass.expanded,
          1200: WindowSizeClass.large,
          1599.9: WindowSizeClass.large,
          1600: WindowSizeClass.extraLarge,
          4000: WindowSizeClass.extraLarge,
        };

        // Act
        final results = cases.map(
          (width, _) => MapEntry(width, WindowSizeClass.fromWidth(width)),
        );

        // Assert
        expect(results, cases);
      });

      test('should treat negative and NaN widths as compact', () {
        // Arrange & Act
        final negative = WindowSizeClass.fromWidth(-10);
        final nan = WindowSizeClass.fromWidth(double.nan);

        // Assert
        expect(negative, WindowSizeClass.compact);
        expect(nan, WindowSizeClass.compact);
      });
    });

    group('isAtLeast', () {
      test('should compare by width order', () {
        // Arrange
        const medium = WindowSizeClass.medium;

        // Act & Assert
        expect(medium.isAtLeast(WindowSizeClass.compact), isTrue);
        expect(medium.isAtLeast(WindowSizeClass.medium), isTrue);
        expect(medium.isAtLeast(WindowSizeClass.expanded), isFalse);
      });
    });

    group('margin', () {
      test('should be 16dp on compact and 24dp otherwise', () {
        // Arrange & Act
        final margins = WindowSizeClass.values.map((c) => c.margin).toList();

        // Assert
        expect(margins, [16, 24, 24, 24, 24]);
      });
    });

    group('of', () {
      testWidgets('should read the MediaQuery width', (tester) async {
        // Arrange
        WindowSizeClass? result;

        // Act
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(700, 900)),
            child: Builder(
              builder: (context) {
                result = WindowSizeClass.of(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // Assert
        expect(result, WindowSizeClass.medium);
      });
    });
  });
}
