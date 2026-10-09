import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches the start of a spacing-bearing call or argument.
///
/// `EdgeInsets` constructors and `Gap(` / `SizedBox(` spacers are checked by
/// their argument list. `spacing:` / `runSpacing:` keywords are checked by the
/// literal that follows them.
final RegExp _spacingCall = RegExp(
  r'\bEdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\('
  r'|\bSizedBox\('
  r'|\bGap\('
  r'|\b(?:spacing|runSpacing)\s*:',
);

/// Matches a numeric literal that is not part of an identifier.
final RegExp _numberLiteral = RegExp(r'(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])');

/// Matches a function call with no nested parentheses, e.g. `density.gap(16)`.
///
/// Numbers passed into a call are treated as call arguments, not as literal
/// spacing, so `density.gap(16)` and `math.max(0, 16)` are not flagged.
final RegExp _innerCall = RegExp(r'[\w.]*\([^()]*\)');

/// Returns the text between the `(` at [open] and its matching `)`.
String _argumentsAt(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return source.substring(open + 1);
}

/// Returns true when [text] has a non-zero numeric literal outside any call.
bool _hasNonZeroLiteral(String text) {
  var stripped = text;
  while (stripped.contains(_innerCall)) {
    stripped = stripped.replaceAll(_innerCall, ' ');
  }
  return _numberLiteral
      .allMatches(stripped)
      .any((match) => double.parse(match.group(1)!) != 0);
}

/// Returns the 1-based line numbers and text of every hardcoded, non-zero
/// spacing value in [source].
///
/// Flags:
/// * `EdgeInsets.all/symmetric/only/fromLTRB/fromSTEB` with a non-zero literal.
/// * `Gap(` with a non-zero literal.
/// * `SizedBox(` spacers (no `child:`) with a non-zero `width:` or `height:`.
/// * `spacing:` / `runSpacing:` set to a non-zero literal.
List<String> findLiteralSpacing(String source) {
  final hits = <String>[];
  for (final match in _spacingCall.allMatches(source)) {
    final token = match.group(0)!;
    final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    final String snippet;
    if (token.endsWith(':')) {
      final value = RegExp(
        r'^\s*(-?\d+(?:\.\d+)?)',
      ).firstMatch(source.substring(match.end));
      if (value == null || double.parse(value.group(1)!) == 0) continue;
      snippet = '$token${value.group(1)}';
    } else {
      final arguments = _argumentsAt(source, match.end - 1);
      if (token.startsWith('SizedBox')) {
        if (arguments.contains('child:')) continue;
        if (!RegExp(r'\b(?:width|height)\s*:').hasMatch(arguments)) continue;
      }
      if (!_hasNonZeroLiteral(arguments)) continue;
      snippet = '$token${arguments.trim()})';
    }
    hits.add('$line: ${snippet.replaceAll('\n', ' ')}');
  }
  return hits;
}

/// Known, reviewed exceptions in the form `path:line`.
///
/// Intentionally empty: structural geometry is expressed without spacing
/// constructors (for example `Positioned`, icon sizes, or `kToolbarHeight`),
/// so nothing in `lib/` needs an exception.
const List<String> _exceptions = <String>[];

void main() {
  group('density spacing literal guard', () {
    group('findLiteralSpacing positive controls', () {
      test('should flag EdgeInsets.all with a literal', () {
        // Arrange
        const source = 'padding: EdgeInsets.all(16),';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, hasLength(1));
      });

      test('should flag EdgeInsets.symmetric with a literal', () {
        // Arrange
        const source = 'padding: const EdgeInsets.symmetric(vertical: 8),';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, hasLength(1));
      });

      test('should flag a multi-line EdgeInsets.only with a literal', () {
        // Arrange
        const source = 'padding: EdgeInsets.only(\n  top: 8,\n  left: 4,\n),';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, hasLength(1));
        expect(hits.first, startsWith('1:'));
      });

      test('should flag Gap with a literal', () {
        // Arrange
        const source = 'children: [Gap(8)],';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, hasLength(1));
      });

      test('should flag a spacer SizedBox with a literal height', () {
        // Arrange
        const source = 'SizedBox(height: 12)';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, hasLength(1));
      });

      test('should flag spacing set to a literal', () {
        // Arrange
        const source = 'Wrap(spacing: 16, runSpacing: 8)';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, hasLength(2));
      });

      test('should flag a literal mixed with a density call', () {
        // Arrange
        const source = 'EdgeInsets.all(density.gap(8) + 4)';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, hasLength(1));
      });
    });

    group('findLiteralSpacing negative controls', () {
      test('should not flag DensitySpacing calls', () {
        // Arrange
        const source =
            'padding: density.all(16, min: 8), '
            'SizedBox(width: density.gap(8)), Gap(density.gap(4)),';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, isEmpty);
      });

      test('should not flag zero-valued spacing', () {
        // Arrange
        const source =
            'EdgeInsets.zero, EdgeInsets.all(0), SizedBox(width: 0),';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, isEmpty);
      });

      test('should not flag a SizedBox that wraps a child', () {
        // Arrange
        const source = 'SizedBox(width: 152, child: Text("x"))';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, isEmpty);
      });

      test('should not flag positional offsets or sizes', () {
        // Arrange
        const source =
            'Positioned(top: 8, child: x), Icon(size: 24), '
            'EdgeInsets.only(top: kToolbarHeight),';

        // Act
        final hits = findLiteralSpacing(source);

        // Assert
        expect(hits, isEmpty);
      });
    });

    test('should have no hardcoded content spacing in lib', () {
      // Arrange
      final violations = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .where((file) => !file.path.endsWith('density_spacing.dart'));

      // Act
      for (final file in files) {
        final path = file.path.replaceAll('\\', '/');
        for (final hit in findLiteralSpacing(file.readAsStringSync())) {
          final key = '$path:${hit.split(':').first}';
          if (_exceptions.contains(key)) continue;
          violations.add('$path:$hit');
        }
      }

      // Assert
      expect(
        violations,
        isEmpty,
        reason:
            'Use DensitySpacing for content spacing:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
