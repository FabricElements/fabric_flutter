import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'catalog/catalog_entries.dart';

/// Development-only Widgetbook catalog for the shared fabric_flutter widgets.
///
/// Run with `flutter run -t widgetbook/main.dart`. This file is not part of
/// the library: nothing under `lib/` imports it, and `widgetbook` is a dev
/// dependency only.
void main() {
  runApp(
    Widgetbook.material(
      directories: [
        WidgetbookFolder(
          name: 'Components',
          children: [
            for (final entry in catalogEntries)
              WidgetbookComponent(
                name: entry.name,
                useCases: [
                  for (final spec in useCaseSpecsFor(entry))
                    WidgetbookUseCase(name: spec.name, builder: spec.builder),
                ],
              ),
          ],
        ),
      ],
    ),
  );
}
