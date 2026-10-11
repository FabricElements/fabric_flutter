import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fabric_flutter/helper/window_size.dart';

import '../../widgetbook/catalog/catalog_entries.dart';
import '../../widgetbook/catalog/catalog_frame.dart';

void main() {
  group('Widgetbook catalog', () {
    group('use cases', () {
      test('should cover light and dark, every density, and every width', () {
        // Arrange
        final variants = CatalogVariant.all;

        // Act
        final brightnesses = variants.map((v) => v.brightness).toSet();
        final densities = variants.map((v) => v.densityName).toSet();
        final sizeClasses = variants.map((v) => v.sizeClass).toSet();

        // Assert
        expect(brightnesses, {Brightness.light, Brightness.dark});
        expect(densities, {'Standard', 'Compact', 'Comfortable'});
        expect(sizeClasses, {
          WindowSizeClass.compact,
          WindowSizeClass.medium,
          WindowSizeClass.expanded,
        });
        expect(variants.length, 2 * 3 * 3);
      });

      test('should give every use case of a component a unique name', () {
        for (final entry in catalogEntries) {
          // Arrange
          final specs = useCaseSpecsFor(entry);

          // Act
          final names = specs.map((spec) => spec.name).toSet();

          // Assert
          expect(names.length, specs.length, reason: entry.name);
        }
      });
    });

    group('golden', () {
      late GoldenFileComparator previousComparator;

      setUpAll(() {
        previousComparator = goldenFileComparator;
        goldenFileComparator = _TolerantGoldenComparator(
          Uri.parse('test/widgetbook/catalog_golden_test.dart'),
        );
      });

      tearDownAll(() => goldenFileComparator = previousComparator);

      for (final entry in catalogEntries) {
        for (final variant in CatalogVariant.all) {
          testWidgets('should render ${entry.name} ${variant.fileKey}', (
            tester,
          ) async {
            // Arrange
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(variant.width, CatalogFrame.height);
            addTearDown(tester.view.reset);
            WindowSizeClass? sizeClass;

            // Act
            await tester.pumpWidget(
              CatalogFrame(
                variant: variant,
                builder: (context) {
                  sizeClass = WindowSizeClass.of(context);
                  return entry.content(context);
                },
              ),
            );
            await tester.pump();

            // Assert
            expect(tester.takeException(), isNull);
            expect(sizeClass, variant.sizeClass);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'goldens/catalog_${entry.name}_${variant.fileKey}.png',
              ),
            );
          });
        }
      }
    });
  });
}

/// Golden comparator that tolerates the small anti-aliasing differences
/// between host platforms (for example macOS versus the Linux CI runner).
class _TolerantGoldenComparator extends LocalFileComparator {
  /// Creates a comparator rooted at [testFile].
  _TolerantGoldenComparator(super.testFile);

  /// Maximum fraction of differing pixels accepted as a match.
  static const double _tolerance = 0.01;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
