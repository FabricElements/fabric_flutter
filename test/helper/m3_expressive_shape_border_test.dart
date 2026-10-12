import 'package:fabric_flutter/helper/m3_expressive_shape_border.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpressiveShapeBorder', () {
    group('lerp', () {
      test('should return the start shape at t 0', () {
        // Arrange & Act
        final shape = ExpressiveShapeBorder.lerp(
          ExpressiveShapeBorder.squircle,
          ExpressiveShapeBorder.cookie,
          0,
        );

        // Assert
        expect(shape, ExpressiveShapeBorder.squircle);
      });

      test('should return the end shape at t 1', () {
        // Arrange & Act
        final shape = ExpressiveShapeBorder.lerp(
          ExpressiveShapeBorder.squircle,
          ExpressiveShapeBorder.cookie,
          1,
        );

        // Assert
        expect(shape, ExpressiveShapeBorder.cookie);
      });

      test('should interpolate the lobe amplitude between the shapes', () {
        // Arrange & Act
        final shape = ExpressiveShapeBorder.lerp(
          ExpressiveShapeBorder.squircle,
          ExpressiveShapeBorder.cookie,
          0.5,
        );

        // Assert
        expect(shape.amplitude, closeTo(0.035, 1e-9));
      });
    });

    group('path', () {
      test('should fill the rect when it has no lobes', () {
        // Arrange
        const rect = Rect.fromLTWH(0, 0, 80, 80);

        // Act
        final bounds = ExpressiveShapeBorder.squircle
            .getOuterPath(rect)
            .getBounds();

        // Assert
        expect(bounds.width, closeTo(80, 0.5));
        expect(bounds.height, closeTo(80, 0.5));
      });

      test('should stay inside the rect when it has lobes', () {
        // Arrange
        const rect = Rect.fromLTWH(0, 0, 80, 80);

        // Act
        final bounds = ExpressiveShapeBorder.cookie
            .getOuterPath(rect)
            .getBounds();

        // Assert
        expect(bounds.width, lessThanOrEqualTo(80.5));
        expect(bounds.height, lessThanOrEqualTo(80.5));
      });
    });

    group('equality', () {
      test('should compare by value', () {
        // Arrange
        const a = ExpressiveShapeBorder(exponent: 3, lobes: 4, amplitude: 0.1);
        const b = ExpressiveShapeBorder(exponent: 3, lobes: 4, amplitude: 0.1);

        // Act & Assert
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
