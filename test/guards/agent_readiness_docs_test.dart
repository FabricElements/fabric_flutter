import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The instructions file that carries the agent-readiness checklist.
const String instructionsPath =
    '.github/instructions/agent-readiness.instructions.md';

/// The canonical repository instruction file that must link to it.
const String copilotInstructionsPath = '.github/copilot-instructions.md';

/// The guard files that enforce the checklist.
const List<String> guardPaths = <String>[
  'test/guards/automation_key_coverage_test.dart',
  'test/guards/agent_command_docs_test.dart',
  'test/guards/agent_element_type_docs_test.dart',
  'test/guards/platform_imports_test.dart',
  'test/guards/agent_readiness_docs_test.dart',
];

/// Returns the `applyTo` value declared in the frontmatter of [source].
String? frontmatterApplyTo(String source) {
  if (!source.startsWith('---')) return null;
  final end = source.indexOf('\n---', 3);
  if (end < 0) return null;
  final match = RegExp(
    '''^applyTo:\\s*["']?([^"'\n]+)["']?''',
    multiLine: true,
  ).firstMatch(source.substring(0, end));
  return match?.group(1)?.trim();
}

/// Returns true when [source] links to [target] in markdown.
bool linksTo(String source, String target) {
  final fileName = target.split('/').last;
  return source.contains(']($target)') ||
      source.contains(']($fileName)') ||
      source.contains('](instructions/$fileName)');
}

void main() {
  group('agent-readiness documentation guard', () {
    group('frontmatterApplyTo', () {
      test('should read a quoted applyTo value', () {
        // Arrange
        const source = '---\napplyTo: "lib/**"\n---\n\n# Title\n';

        // Act & Assert
        expect(frontmatterApplyTo(source), 'lib/**');
      });

      test('should return null without frontmatter', () {
        // Arrange
        const source = '# Title\n\napplyTo: "lib/**"\n';

        // Act & Assert
        expect(frontmatterApplyTo(source), isNull);
      });
    });

    group('linksTo', () {
      test('should match a relative markdown link', () {
        // Arrange & Act & Assert
        expect(
          linksTo(
            'see [x](instructions/agent-readiness.instructions.md)',
            instructionsPath,
          ),
          isTrue,
        );
      });

      test('should not match a bare mention', () {
        // Arrange & Act & Assert
        expect(
          linksTo('see agent-readiness.instructions.md', instructionsPath),
          isFalse,
        );
      });
    });

    test('should ship the agent-readiness instructions file', () {
      // Arrange
      final file = File(instructionsPath);

      // Act & Assert
      expect(
        file.existsSync(),
        isTrue,
        reason: '$instructionsPath must exist to document the checklist.',
      );
      expect(
        frontmatterApplyTo(file.readAsStringSync()),
        'lib/**',
        reason: '$instructionsPath must scope itself to lib/**.',
      );
    });

    test('should link the instructions file from copilot-instructions.md', () {
      // Arrange
      final source = File(copilotInstructionsPath).readAsStringSync();

      // Act & Assert
      expect(
        linksTo(source, instructionsPath),
        isTrue,
        reason:
            '$copilotInstructionsPath must link to $instructionsPath so the '
            'checklist is discoverable.',
      );
    });

    test('should ship every guard file', () {
      // Arrange & Act
      final missing = guardPaths
          .where((path) => !File(path).existsSync())
          .toList();

      // Assert
      expect(
        missing,
        isEmpty,
        reason: 'Missing guard files:\n${missing.join('\n')}',
      );
    });

    test('should reference every guard file from the instructions file', () {
      // Arrange
      final source = File(instructionsPath).readAsStringSync();

      // Act
      final unreferenced = guardPaths
          .where((path) => !source.contains(path.split('/').last))
          .toList();

      // Assert
      expect(
        unreferenced,
        isEmpty,
        reason:
            'The instructions file must name each guard that enforces it:\n'
            '${unreferenced.join('\n')}',
      );
    });
  });
}
