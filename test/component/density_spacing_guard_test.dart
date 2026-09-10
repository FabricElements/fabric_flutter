import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _GuardSnippet {
  const _GuardSnippet(this.path, this.snippet, this.reason);

  final String path;
  final String snippet;
  final String reason;
}

bool _matchesGuardSnippet({
  required String relativePath,
  required String line,
  required List<_GuardSnippet> snippets,
}) {
  return snippets.any(
    (entry) => entry.path == relativePath && line.contains(entry.snippet),
  );
}

bool _matchesLiteralSpacingPattern(String line) {
  final literalSpacingPatterns = <RegExp>[
    RegExp(r'\bGap\(\s*(?:const\s+)?\d+(?:\.\d+)?'),
    RegExp(r'\bSizedBox\([^)]*(?:width|height):\s*(?:const\s+)?\d+(?:\.\d+)?'),
    RegExp(r'\b(?:spacing|runSpacing):\s*(?:const\s+)?\d+(?:\.\d+)?'),
  ];
  return literalSpacingPatterns.any((pattern) => pattern.hasMatch(line));
}

bool _hasNumericEdgeInsetsLiteral(String line) {
  return RegExp(
    r'\bEdgeInsets\.(?:all|symmetric|only)\([^)]*\d+(?:\.\d+)?',
  ).hasMatch(line);
}

bool _isOrdinaryContentSpacingCandidate({
  required String line,
  required String previousSignificantLine,
}) {
  if (_matchesLiteralSpacingPattern(line)) return true;

  if (!_hasNumericEdgeInsetsLiteral(line)) return false;
  if (line.contains('contentPadding:')) return true;
  if (!line.contains('padding:')) return false;

  return previousSignificantLine.contains('Padding(') ||
      previousSignificantLine.contains('SliverPadding(') ||
      previousSignificantLine.contains('Markdown(');
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
      final allowed = <_GuardSnippet>[];

      final issues = <String>[];

      for (final sourceRoot in sourceRoots) {
        final directory = Directory('$root/$sourceRoot');
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File) continue;
          final path = entity.path.replaceAll('\\', '/');
          if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
          final relativePath = path.substring(root.length + 1);
          final lines = entity.readAsLinesSync();
          String previousSignificantLine = '';

          for (var index = 0; index < lines.length; index++) {
            final line = lines[index].trim();
            if (line.startsWith('//') || line.startsWith('*')) continue;

            if (!_isOrdinaryContentSpacingCandidate(
              line: line,
              previousSignificantLine: previousSignificantLine,
            )) {
              previousSignificantLine = line;
              continue;
            }

            final isAllowed = _matchesGuardSnippet(
              relativePath: relativePath,
              line: line,
              snippets: allowed,
            );
            if (isAllowed) continue;

            issues.add('$relativePath:${index + 1}: $line');

            previousSignificantLine = line;
            continue;
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
            'a short rationale. Do not use the allowlist for ordinary UI '
            'spacing that should still flow through DensitySpacing.',
      );
    });

    test(
      'should keep the exception mechanism available with an empty baseline',
      () {
        // Arrange
        const allowed = <_GuardSnippet>[];
        const allowedEntry = _GuardSnippet(
          'lib/component/example.dart',
          'const EdgeInsets.all(12)',
          'example structural geometry',
        );

        // Act
        final matches = _matchesGuardSnippet(
          relativePath: allowedEntry.path,
          line: 'padding: const EdgeInsets.all(12),',
          snippets: <_GuardSnippet>[allowedEntry, ...allowed],
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
