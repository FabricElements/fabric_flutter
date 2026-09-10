import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _AllowedSnippet {
  const _AllowedSnippet(this.path, this.snippet, this.reason);

  final String path;
  final String snippet;
  final String reason;
}

class _ExcludedSnippet {
  const _ExcludedSnippet(this.path, this.snippet, this.reason);

  final String path;
  final String snippet;
  final String reason;
}

bool _isAllowedSnippet({
  required String relativePath,
  required String line,
  required List<_AllowedSnippet> allowed,
}) {
  return allowed.any(
    (entry) => entry.path == relativePath && line.contains(entry.snippet),
  );
}

bool _isExcludedSnippet({
  required String relativePath,
  required String line,
  required List<_ExcludedSnippet> excluded,
}) {
  return excluded.any(
    (entry) => entry.path == relativePath && line.contains(entry.snippet),
  );
}

bool _matchesLiteralSpacingPattern(String line) {
  final literalSpacingPatterns = <RegExp>[
    RegExp(r'\bGap\(\s*(?:const\s+)?\d+(?:\.\d+)?'),
    RegExp(r'\bSizedBox\([^)]*(?:width|height):\s*(?:const\s+)?\d+(?:\.\d+)?'),
    RegExp(r'\bEdgeInsets\.(?:all|symmetric|only)\([^)]*\d+(?:\.\d+)?'),
    RegExp(r'\b(?:spacing|runSpacing):\s*(?:const\s+)?\d+(?:\.\d+)?'),
  ];
  return literalSpacingPatterns.any((pattern) => pattern.hasMatch(line));
}

void main() {
  group('Density spacing source guard', () {
    test('should keep literal content spacing on the DensitySpacing path', () {
      // Arrange
      // The allowlist stays empty by default. If a future fixed-spacing case
      // is genuinely justified after review, add one explicit entry here with
      // the exact file path and source snippet plus an accessibility,
      // structural, or navigation rationale. Do not use the mechanism to
      // bypass ordinary UI spacing that should still flow through
      // DensitySpacing.
      final root = Directory.current.path;
      final sourceRoots = <String>['lib/component', 'lib/view'];
      final allowed = <_AllowedSnippet>[];
      final excluded = <_ExcludedSnippet>[
        // These are not content-spacing exceptions; they are scope filters for
        // known structural or navigation geometry that intentionally stays
        // fixed even when DensitySpacing is available.
        const _ExcludedSnippet(
          'lib/component/pagination_nav.dart',
          'const SizedBox(width: 4)',
          'pagination controls use a fixed chrome gap',
        ),
        const _ExcludedSnippet(
          'lib/component/managed_drop_zone.dart',
          'kMinInteractiveDimension * 4',
          'drop-zone surface uses a fixed accessibility shell',
        ),
        const _ExcludedSnippet(
          'lib/component/managed_drop_zone.dart',
          'const EdgeInsets.all(16)',
          'drop-zone outer margin is structural geometry',
        ),
        const _ExcludedSnippet(
          'lib/component/managed_drop_zone.dart',
          'const EdgeInsets.all(4)',
          'drop-zone painter padding is part of the shell',
        ),
        const _ExcludedSnippet(
          'lib/component/managed_drop_zone.dart',
          'const EdgeInsets.all(8)',
          'drop-zone label inset is part of the shell',
        ),
        const _ExcludedSnippet(
          'lib/component/logs_list.dart',
          'const SizedBox(height: 0)',
          'logs list placeholder keeps a fixed zero-height sentinel',
        ),
        const _ExcludedSnippet(
          'lib/component/user_admin.dart',
          'const EdgeInsets.all(0)',
          'role chips intentionally keep zero internal padding',
        ),
        const _ExcludedSnippet(
          'lib/component/upload_image_media.dart',
          'EdgeInsets.all(((48 - effectiveIconSize) / 2).clamp(0, 24))',
          'icon-button padding is derived from a fixed control size',
        ),
        const _ExcludedSnippet(
          'lib/component/card_button.dart',
          'const EdgeInsets.symmetric(vertical: 8)',
          'pressable card shell keeps a fixed outer touch target',
        ),
        const _ExcludedSnippet(
          'lib/view/view_hero.dart',
          'boundaryMargin: const EdgeInsets.all(16)',
          'hero route boundary margin is navigation geometry',
        ),
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

            if (!_matchesLiteralSpacingPattern(line)) continue;

            final isExcluded = _isExcludedSnippet(
              relativePath: relativePath,
              line: line,
              excluded: excluded,
            );
            if (isExcluded) continue;

            final isAllowed = _isAllowedSnippet(
              relativePath: relativePath,
              line: line,
              allowed: allowed,
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
            'intentional, add a documented allowlist entry in this guard with '
            'a short rationale. Structural/navigation scope filters remain '
            'separate from the allowlist and should stay explicit.',
      );
    });

    test(
      'should keep the exception mechanism available with an empty baseline',
      () {
        // Arrange
        const allowed = <_AllowedSnippet>[];
        const allowedEntry = _AllowedSnippet(
          'lib/component/example.dart',
          'const EdgeInsets.all(12)',
          'example structural geometry',
        );

        // Act
        final matches = _isAllowedSnippet(
          relativePath: allowedEntry.path,
          line: 'padding: const EdgeInsets.all(12),',
          allowed: <_AllowedSnippet>[allowedEntry, ...allowed],
        );

        // Assert
        expect(allowed, isEmpty);
        expect(matches, isTrue);
      },
    );

    test('should accept shrink boxes and detect explicit zero-sized boxes', () {
      // Arrange
      const shrinkLine = 'return const SizedBox.shrink();';
      const zeroLine = 'return const SizedBox(width: 0, height: 0);';

      // Act
      final shrinkMatches = _matchesLiteralSpacingPattern(shrinkLine);
      final zeroMatches = _matchesLiteralSpacingPattern(zeroLine);

      // Assert
      expect(shrinkMatches, isFalse);
      expect(zeroMatches, isTrue);
    });
  });
}
