import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _AllowedSnippet {
  const _AllowedSnippet(this.path, this.snippet, this.reason);

  final String path;
  final String snippet;
  final String reason;
}

void main() {
  group('Density spacing source guard', () {
    test('should keep literal content spacing on the DensitySpacing path', () {
      // Arrange
      final root = Directory.current.path;
      final sourceRoots = <String>['lib/component', 'lib/view'];
      final allowed = <_AllowedSnippet>[
        // Structural / accessibility geometry that must stay fixed.
        const _AllowedSnippet(
          'lib/component/managed_drop_zone.dart',
          'kMinInteractiveDimension * 4',
          'drop-zone surface uses a fixed accessibility shell',
        ),
        const _AllowedSnippet(
          'lib/component/managed_drop_zone.dart',
          'const EdgeInsets.all(16)',
          'drop-zone outer margin is structural geometry',
        ),
        const _AllowedSnippet(
          'lib/component/managed_drop_zone.dart',
          'const EdgeInsets.all(4)',
          'drop-zone painter padding is part of the shell',
        ),
        const _AllowedSnippet(
          'lib/component/managed_drop_zone.dart',
          'const EdgeInsets.all(8)',
          'drop-zone label inset is part of the shell',
        ),
        const _AllowedSnippet(
          'lib/component/google_chart_container.dart',
          'const EdgeInsets.only(top: 8)',
          'chart editor frame inset is fixed by design',
        ),
        const _AllowedSnippet(
          'lib/component/google_chart_container.dart',
          'const EdgeInsets.symmetric(vertical: 16, horizontal: 16)',
          'chart shell spacing is layout geometry',
        ),
        const _AllowedSnippet(
          'lib/component/google_chart_container.dart',
          'const EdgeInsets.all(16.0)',
          'chart control padding is part of the layout shell',
        ),
        const _AllowedSnippet(
          'lib/component/card_button.dart',
          'const EdgeInsets.symmetric(vertical: 8)',
          'pressable card shell keeps a fixed outer touch target',
        ),
        const _AllowedSnippet(
          'lib/component/card_button.dart',
          'const EdgeInsets.only(top: 8)',
          'card subtitle inset is part of the action surface',
        ),
        const _AllowedSnippet(
          'lib/component/stepper_extended.dart',
          'const EdgeInsets.only(top: 16, bottom: 32, left: 0, right: 16)',
          'step geometry is structural layout, not content spacing',
        ),
        const _AllowedSnippet(
          'lib/component/stepper_extended.dart',
          'spacing: 16,',
          'step content separation is fixed structural rhythm',
        ),
        const _AllowedSnippet(
          'lib/component/stepper_extended.dart',
          'const EdgeInsets.only(top: 8)',
          'step subtitle inset is part of the layout shell',
        ),
        const _AllowedSnippet(
          'lib/component/stepper_extended.dart',
          'const EdgeInsets.only(left: 32)',
          'step rail indentation is structural geometry',
        ),
        const _AllowedSnippet(
          'lib/component/breadcrumbs.dart',
          'const EdgeInsets.symmetric(horizontal: 16)',
          'breadcrumbs keep a fixed navigation shell inset',
        ),
        const _AllowedSnippet(
          'lib/component/input_data.dart',
          'const EdgeInsets.symmetric(horizontal: 12, vertical: 8)',
          'input chrome padding is a control geometry constant',
        ),
        const _AllowedSnippet(
          'lib/component/input_data.dart',
          'const EdgeInsets.symmetric(horizontal: 4, vertical: 4)',
          'prefix chrome padding is part of the control shell',
        ),
        const _AllowedSnippet(
          'lib/component/json_explorer_search.dart',
          'const EdgeInsets.only(top: 4, right: 4)',
          'search panel chrome keeps a fixed frame inset',
        ),
        const _AllowedSnippet(
          'lib/component/user_admin.dart',
          'const EdgeInsets.all(0)',
          'role chips intentionally keep zero internal padding',
        ),
        const _AllowedSnippet(
          'lib/component/logs_list.dart',
          'const EdgeInsets.symmetric(vertical: 8)',
          'log list shell spacing is intentional layout geometry',
        ),
        const _AllowedSnippet(
          'lib/component/logs_list.dart',
          'const EdgeInsets.only(bottom: 4.0)',
          'log item footer inset is structural spacing',
        ),
        const _AllowedSnippet(
          'lib/component/logs_list.dart',
          'const EdgeInsets.only(left: 8.0)',
          'log item chrome indentation is layout geometry',
        ),
        const _AllowedSnippet(
          'lib/component/logs_list.dart',
          'const EdgeInsets.only(top: 8)',
          'log item child inset is structural spacing',
        ),
        const _AllowedSnippet(
          'lib/component/connection_status.dart',
          'EdgeInsets.all(35)',
          'status badge spacing is an explicit visual dimension',
        ),
        const _AllowedSnippet(
          'lib/component/connection_status.dart',
          'spacing: 16,',
          'status indicator row keeps a fixed structural gap',
        ),
        const _AllowedSnippet(
          'lib/component/smart_button.dart',
          'const EdgeInsets.all(8)',
          'button chrome padding is a control geometry constant',
        ),
        const _AllowedSnippet(
          'lib/component/pagination_nav.dart',
          'const SizedBox(width: 4)',
          'pagination controls use a fixed chrome gap',
        ),
        const _AllowedSnippet(
          'lib/component/user_chip.dart',
          'const SizedBox(width: 0, height: 0)',
          'zero-sized chip placeholder is intentional structural geometry',
        ),
        const _AllowedSnippet(
          'lib/component/logs_list.dart',
          'const SizedBox(height: 0)',
          'logs list placeholder keeps a fixed zero-height sentinel',
        ),
        const _AllowedSnippet(
          'lib/component/expansion_table.dart',
          'const SizedBox(height: 32)',
          'table expansion spacing is structural content framing',
        ),
        const _AllowedSnippet(
          'lib/view/view_hero.dart',
          'boundaryMargin: const EdgeInsets.all(16)',
          'hero route boundary margin is navigation geometry',
        ),
        const _AllowedSnippet(
          'lib/component/upload_image_media.dart',
          'EdgeInsets.all(((48 - effectiveIconSize) / 2).clamp(0, 24))',
          'icon-button padding is derived from a fixed control size',
        ),
      ];

      final literalSpacingPatterns = <RegExp>[
        RegExp(r'\bGap\(\s*(?:const\s+)?\d+(?:\.\d+)?'),
        RegExp(
          r'\bSizedBox\([^)]*(?:width|height):\s*(?:const\s+)?\d+(?:\.\d+)?',
        ),
        RegExp(r'\bEdgeInsets\.(?:all|symmetric|only)\([^)]*\d+(?:\.\d+)?'),
        RegExp(r'\b(?:spacing|runSpacing):\s*(?:const\s+)?\d+(?:\.\d+)?'),
      ];

      final issues = <String>[];

      for (final sourceRoot in sourceRoots) {
        final directory = Directory('$root/$sourceRoot');
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File) continue;
          final path = entity.path.replaceAll('\\', '/');
          if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
          final relativePath = path.substring(root.length + 1);
          final lines = entity.readAsLinesSync();

          for (var index = 0; index < lines.length; index++) {
            final line = lines[index].trim();
            if (line.startsWith('//') || line.startsWith('*')) continue;

            final matchedPattern = literalSpacingPatterns.any(
              (pattern) => pattern.hasMatch(line),
            );
            if (!matchedPattern) continue;

            final isAllowed = allowed.any(
              (entry) =>
                  entry.path == relativePath && line.contains(entry.snippet),
            );
            if (isAllowed) continue;

            issues.add('$relativePath:${index + 1}: $line');
          }
        }
      }

      // Act / Assert
      expect(
        issues,
        isEmpty,
        reason:
            'Found literal content spacing that should use DensitySpacing or '
            'be documented as a justified exception:\n'
            '${issues.join('\n')}\n\n'
            'Use DensitySpacing for content gaps. If fixed geometry is truly '
            'intentional, keep it in a documented allowlist entry in this '
            'guard with a short rationale.',
      );
    });
  });
}
