import 'package:flutter/material.dart';
import 'package:fabric_flutter/component/adaptive_navigation_scaffold.dart';
import 'package:fabric_flutter/component/card_button.dart';
import 'package:fabric_flutter/component/section_title.dart';
import 'package:fabric_flutter/component/smart_button.dart';
import 'package:fabric_flutter/component/status_chip.dart';
import 'package:fabric_flutter/helper/density_spacing.dart';
import 'package:fabric_flutter/helper/options.dart';

import 'catalog_frame.dart';

/// One reusable widget in the catalog, with the content it renders.
class CatalogEntry {
  /// Creates an entry named [name] that renders [content].
  const CatalogEntry({required this.name, required this.content});

  /// Stable, file-safe name used in use case and golden names.
  final String name;

  /// Builds the widget under test; runs inside [CatalogFrame].
  final WidgetBuilder content;
}

/// Every widget covered by the catalog, in display order.
///
/// Cards and buttons come first because they are the most reused. Each entry
/// is rendered for every [CatalogVariant], so one use case per variant exists
/// for each entry.
final List<CatalogEntry> catalogEntries = [
  CatalogEntry(
    name: 'card_button',
    content: (context) => Padding(
      padding: DensitySpacing.of(context).all(8),
      child: CardButton(
        headline: 'Card button',
        description: 'Tap target with overlay text',
        image: '',
        onPressed: () {},
      ),
    ),
  ),
  CatalogEntry(
    name: 'smart_button',
    content: (context) => Padding(
      padding: DensitySpacing.of(context).all(8),
      child: SmartButton(
        button: ButtonOptions(
          label: 'Save profile',
          icon: Icons.save_outlined,
          path: '/save',
        ),
      ),
    ),
  ),
  CatalogEntry(
    name: 'status_chip',
    content: (context) {
      final density = DensitySpacing.of(context);
      return Padding(
        padding: density.all(8),
        child: Wrap(
          spacing: density.gap(8),
          runSpacing: density.gap(8),
          children: const [
            StatusChip(status: 'active'),
            StatusChip(status: 'pending'),
            StatusChip(status: 'error'),
          ],
        ),
      );
    },
  ),
  CatalogEntry(
    name: 'section_title',
    content: (context) => Padding(
      padding: DensitySpacing.of(context).all(8),
      child: const SectionTitle(
        headline: 'Welcome to {Fabric}',
        description: 'Informational header shown above a section.',
      ),
    ),
  ),
  CatalogEntry(
    name: 'adaptive_navigation_scaffold',
    content: (context) => AdaptiveNavigationScaffold(
      destinations: const [
        AdaptiveDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        AdaptiveDestination(icon: Icon(Icons.search_outlined), label: 'Search'),
        AdaptiveDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      appBar: AppBar(title: const Text('Catalog')),
      body: const Center(child: Text('Body')),
      semanticsLabel: 'Main navigation',
      automationKey: 'catalog_nav_main',
    ),
  ),
];

/// Builds the Widgetbook use cases for [entry]: one per [CatalogVariant].
List<WidgetbookUseCaseSpec> useCaseSpecsFor(CatalogEntry entry) {
  return [
    for (final variant in CatalogVariant.all)
      WidgetbookUseCaseSpec(
        name: variant.name,
        builder: (context) =>
            CatalogFrame(variant: variant, builder: entry.content),
      ),
  ];
}

/// A use case name and the builder that renders it, independent of the
/// Widgetbook runtime so the same specs can drive golden tests.
class WidgetbookUseCaseSpec {
  /// Creates a spec named [name] rendered by [builder].
  const WidgetbookUseCaseSpec({required this.name, required this.builder});

  /// Display name of the use case.
  final String name;

  /// Builds the use case widget.
  final WidgetBuilder builder;
}
