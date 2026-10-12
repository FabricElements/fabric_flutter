import 'package:fabric_flutter/helper/density_text_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('densityTextScale', () {
    test('should return 1.0 for standard density', () {
      expect(densityTextScale(VisualDensity.standard), 1.0);
    });

    test('should shrink by 4% per step below standard', () {
      expect(densityTextScale(VisualDensity.comfortable), closeTo(0.96, 1e-9));
      expect(densityTextScale(VisualDensity.compact), closeTo(0.92, 1e-9));
    });

    test('should grow by 8% per step above standard', () {
      expect(
        densityTextScale(const VisualDensity(horizontal: 1, vertical: 1)),
        closeTo(1.08, 1e-9),
      );
      expect(
        densityTextScale(const VisualDensity(horizontal: 2, vertical: 2)),
        closeTo(1.16, 1e-9),
      );
    });
  });

  group('DensityTextScaler', () {
    testWidgets('should scale text inside its subtree', (tester) async {
      Future<double> heightAt(VisualDensity density) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DensityTextScaler(
                density: density,
                child: const Text(
                  'Scale',
                  style: TextStyle(fontSize: 16, height: 1),
                ),
              ),
            ),
          ),
        );
        return tester.getSize(find.text('Scale')).height;
      }

      final standard = await heightAt(VisualDensity.standard);
      final large = await heightAt(
        const VisualDensity(horizontal: 2, vertical: 2),
      );
      expect(large, greaterThan(standard));
    });
  });
}
