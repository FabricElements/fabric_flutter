import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fabric_flutter/helper/m3_tokens.dart';
import 'package:fabric_flutter/helper/material_theme.dart';
import 'package:fabric_flutter/helper/window_size.dart';

void main() {
  group('MaterialThemeM3', () {
    group('apply', () {
      test('should keep the base typography', () {
        // Arrange
        final base = ThemeData(
          textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 21)),
        );

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.textTheme.bodyLarge?.fontSize, 21);
      });

      test('should keep the base color scheme', () {
        // Arrange
        final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
        final base = ThemeData(colorScheme: scheme);

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.colorScheme, scheme);
      });

      test('should use surfaceContainerLow for cards without tint', () {
        // Arrange
        final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
        final base = ThemeData(colorScheme: scheme);

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.cardTheme.color, scheme.surfaceContainerLow);
        expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
        expect(theme.cardTheme.elevation, 0);
      });

      test('should use surfaceContainerHigh for dialogs without tint', () {
        // Arrange
        final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
        final base = ThemeData(colorScheme: scheme);

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.dialogTheme.backgroundColor, scheme.surfaceContainerHigh);
        expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
        expect(theme.dialogTheme.elevation, 0);
      });
    });

    for (final brightness in Brightness.values) {
      group('component themes (${brightness.name})', () {
        late ColorScheme scheme;
        late ThemeData theme;

        setUp(() {
          scheme = ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: brightness,
          );
          theme = MaterialThemeM3.apply(ThemeData(colorScheme: scheme));
        });

        test('should keep the app bar flat on surface', () {
          // Assert
          expect(theme.appBarTheme.backgroundColor, scheme.surface);
          expect(theme.appBarTheme.foregroundColor, scheme.onSurface);
          expect(theme.appBarTheme.elevation, 0);
          expect(theme.appBarTheme.scrolledUnderElevation, 0);
          expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
        });

        test('should use tonal navigation bar and rail', () {
          // Assert
          expect(
            theme.navigationBarTheme.backgroundColor,
            scheme.surfaceContainer,
          );
          expect(
            theme.navigationBarTheme.indicatorColor,
            scheme.secondaryContainer,
          );
          expect(theme.navigationBarTheme.elevation, 0);
          expect(theme.navigationRailTheme.backgroundColor, scheme.surface);
          expect(
            theme.navigationRailTheme.indicatorColor,
            scheme.secondaryContainer,
          );
          expect(theme.navigationRailTheme.elevation, 0);
        });

        test('should keep the drawer flat on surfaceContainerLow', () {
          // Assert
          expect(theme.drawerTheme.backgroundColor, scheme.surfaceContainerLow);
          expect(theme.drawerTheme.elevation, 0);
          expect(theme.drawerTheme.surfaceTintColor, Colors.transparent);
        });

        test('should use a flat primaryContainer FAB', () {
          // Arrange
          final fab = theme.floatingActionButtonTheme;

          // Assert
          expect(fab.backgroundColor, scheme.primaryContainer);
          expect(fab.foregroundColor, scheme.onPrimaryContainer);
          expect(fab.elevation, 0);
          expect(fab.focusElevation, 0);
          expect(fab.hoverElevation, 0);
          expect(fab.highlightElevation, 0);
          expect(
            fab.shape,
            RoundedRectangleBorder(
              borderRadius: M3Shape.circular(M3Shape.large),
            ),
          );
        });

        test('should outline chips with outlineVariant', () {
          // Assert
          expect(
            theme.chipTheme.side,
            BorderSide(color: scheme.outlineVariant),
          );
          expect(theme.chipTheme.elevation, 0);
        });

        test('should use outlined inputs with the extraSmall corner', () {
          // Arrange
          final input = theme.inputDecorationTheme;
          final radius = M3Shape.circular(M3Shape.extraSmall);

          // Assert
          expect(input.border, OutlineInputBorder(borderRadius: radius));
          expect(
            input.enabledBorder,
            OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.outline),
            ),
          );
          expect(
            input.focusedBorder,
            OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.primary, width: 2),
            ),
          );
          expect(input.errorBorder, isA<OutlineInputBorder>());
          expect(input.disabledBorder, isA<OutlineInputBorder>());
        });

        test('should float snack bars on inverseSurface', () {
          // Assert
          expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
          expect(theme.snackBarTheme.backgroundColor, scheme.inverseSurface);
          expect(theme.snackBarTheme.actionTextColor, scheme.inversePrimary);
        });

        test('should keep bottom sheets and menus flat and tonal', () {
          // Assert
          expect(
            theme.bottomSheetTheme.backgroundColor,
            scheme.surfaceContainerLow,
          );
          expect(theme.bottomSheetTheme.elevation, 0);
          expect(theme.bottomSheetTheme.modalElevation, 0);
          expect(theme.popupMenuTheme.color, scheme.surfaceContainer);
          expect(theme.popupMenuTheme.elevation, 0);
        });

        test('should draw tooltips on inverseSurface', () {
          // Arrange
          final decoration = theme.tooltipTheme.decoration as BoxDecoration?;

          // Assert
          expect(decoration?.color, scheme.inverseSurface);
          expect(
            decoration?.borderRadius,
            M3Shape.circular(M3Shape.extraSmall),
          );
        });
      });
    }

    group('consumer overrides', () {
      test('should preserve values the base theme already sets', () {
        // Arrange
        final base = ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          appBarTheme: const AppBarThemeData(
            elevation: 3,
            backgroundColor: Colors.red,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.green,
            elevation: 6,
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.fixed,
          ),
          inputDecorationTheme: const InputDecorationThemeData(
            border: UnderlineInputBorder(),
          ),
          tooltipTheme: const TooltipThemeData(
            decoration: BoxDecoration(color: Colors.amber),
          ),
        );

        // Act
        final theme = MaterialThemeM3.apply(base);

        // Assert
        expect(theme.appBarTheme.elevation, 3);
        expect(theme.appBarTheme.backgroundColor, Colors.red);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.floatingActionButtonTheme.backgroundColor, Colors.green);
        expect(theme.floatingActionButtonTheme.elevation, 6);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.fixed);
        expect(theme.inputDecorationTheme.border, const UnderlineInputBorder());
        expect(
          (theme.tooltipTheme.decoration as BoxDecoration?)?.color,
          Colors.amber,
        );
      });
    });

    group('responsive render', () {
      late GoldenFileComparator previousComparator;

      setUpAll(() {
        previousComparator = goldenFileComparator;
        goldenFileComparator = _TolerantGoldenComparator(
          Uri.parse('test/helper/material_theme_test.dart'),
        );
      });

      tearDownAll(() => goldenFileComparator = previousComparator);

      final widths = <double, WindowSizeClass>{
        390: WindowSizeClass.compact,
        700: WindowSizeClass.medium,
        1000: WindowSizeClass.expanded,
      };

      for (final brightness in Brightness.values) {
        for (final entry in widths.entries) {
          testWidgets('should render flat at ${entry.key.toInt()}dp '
              '(${brightness.name})', (tester) async {
            // Arrange
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(entry.key, 800);
            addTearDown(tester.view.reset);
            final theme = MaterialThemeM3.apply(
              ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.indigo,
                  brightness: brightness,
                ),
                visualDensity: VisualDensity.adaptivePlatformDensity,
              ),
            );
            WindowSizeClass? sizeClass;

            // Act
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: Builder(
                  builder: (context) {
                    sizeClass = WindowSizeClass.of(context);
                    final compact = sizeClass == WindowSizeClass.compact;
                    const destinations = [
                      (Icons.home_outlined, 'Home'),
                      (Icons.settings_outlined, 'Settings'),
                    ];
                    return Scaffold(
                      appBar: AppBar(title: const Text('Title')),
                      floatingActionButton: FloatingActionButton(
                        onPressed: () {},
                        child: const Icon(Icons.add),
                      ),
                      bottomNavigationBar: compact
                          ? NavigationBar(
                              destinations: [
                                for (final d in destinations)
                                  NavigationDestination(
                                    icon: Icon(d.$1),
                                    label: d.$2,
                                  ),
                              ],
                            )
                          : null,
                      body: Row(
                        children: [
                          if (!compact)
                            NavigationRail(
                              selectedIndex: 0,
                              labelType: NavigationRailLabelType.all,
                              destinations: [
                                for (final d in destinations)
                                  NavigationRailDestination(
                                    icon: Icon(d.$1),
                                    label: Text(d.$2),
                                  ),
                              ],
                            ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Card(child: ListTile(title: Text('Card'))),
                                  TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Input',
                                    ),
                                  ),
                                  Chip(label: Text('Chip')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );

            // Assert
            expect(tester.takeException(), isNull);
            expect(sizeClass, entry.value);
            final appBarMaterial = tester.widget<Material>(
              find
                  .descendant(
                    of: find.byType(AppBar),
                    matching: find.byType(Material),
                  )
                  .first,
            );
            expect(appBarMaterial.elevation, 0);
            expect(appBarMaterial.color, theme.colorScheme.surface);
            expect(
              find.byType(NavigationBar),
              entry.value == WindowSizeClass.compact
                  ? findsOneWidget
                  : findsNothing,
            );
            expect(
              find.byType(NavigationRail),
              entry.value == WindowSizeClass.compact
                  ? findsNothing
                  : findsOneWidget,
            );
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'goldens/material_theme_${entry.key.toInt()}_'
                '${brightness.name}.png',
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
