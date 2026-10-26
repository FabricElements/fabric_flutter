import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches a built-in command id literal in `agent_builtin_commands.dart`.
///
/// Commands are declared as `AgentCommand.define(id: 'navigate', …)`, so the
/// id literal is what the registry actually installs — reading the source
/// avoids depending on a configured bridge instance.
final RegExp commandIdLiteral = RegExp("""id:\\s*'([^']+)'""");

/// Returns every built-in command id literal declared in [source].
List<String> findCommandIdLiterals(String source) => commandIdLiteral
    .allMatches(source)
    .map((match) => match.group(1)!)
    .toList(growable: false);

/// Returns true when [doc] documents [commandId].
///
/// A command is documented when the doc contains it as a heading
/// (`### `id``) or inside a table row / inline-code span that names it.
bool documentsCommand(String doc, String commandId) {
  if (doc.contains('`$commandId`')) return true;
  return RegExp(
    '(^|\\W)${RegExp.escape(commandId)}(\\W|\$)',
    multiLine: true,
  ).hasMatch(doc);
}

/// Built-in commands that are intentionally not documented as a `doc/agent.md`
/// §3 heading because they are covered elsewhere in the document.
///
/// Empty: every registered id currently has a §3 entry.
const List<String> undocumentedExceptions = <String>[];

void main() {
  group('agent command documentation guard', () {
    group('findCommandIdLiterals', () {
      test('should extract command ids from define calls', () {
        // Arrange
        const source = '''
final commands = [
  AgentCommand.define(id: 'navigate', title: 'x'),
  AgentCommand.define(id: 'element.reveal', title: 'y'),
];
''';

        // Act
        final ids = findCommandIdLiterals(source);

        // Assert
        expect(ids, ['navigate', 'element.reveal']);
      });

      test('should return an empty list for source without commands', () {
        // Arrange
        const source = 'final commands = <AgentCommand>[];';

        // Act
        final ids = findCommandIdLiterals(source);

        // Assert
        expect(ids, isEmpty);
      });
    });

    group('documentsCommand', () {
      test('should match a dotted command id in inline code', () {
        // Arrange & Act & Assert
        expect(
          documentsCommand('### `element.reveal`', 'element.reveal'),
          isTrue,
        );
      });

      test('should match a plain command id in a table row', () {
        // Arrange & Act & Assert
        expect(documentsCommand('| `read_value` | x |', 'read_value'), isTrue);
      });

      test('should not match an unrelated id', () {
        // Arrange & Act & Assert
        expect(documentsCommand('### `navigate`', 'set_value'), isFalse);
      });

      test('should not match a substring of a longer id', () {
        // Arrange & Act & Assert
        expect(documentsCommand('### `navigator`', 'navigate'), isFalse);
      });
    });

    test('should document every built-in command in doc/agent.md', () {
      // Arrange
      final source = File('lib/helper/agent/agent_builtin_commands.dart')
          .readAsStringSync();
      final doc = File('doc/agent.md').readAsStringSync();
      final ids = findCommandIdLiterals(source);

      // Act
      final undocumented = ids
          .where((id) => !undocumentedExceptions.contains(id))
          .where((id) => !documentsCommand(doc, id))
          .toList();

      // Assert
      expect(
        ids,
        isNotEmpty,
        reason: 'No built-in command ids were found to check.',
      );
      expect(
        undocumented,
        isEmpty,
        reason:
            'Document every built-in command in doc/agent.md §3 '
            '(see .github/instructions/agent-readiness.instructions.md §3):\n'
            '${undocumented.join('\n')}',
      );
    });

    test('should keep the undocumented exception list minimal', () {
      // Arrange
      final source = File('lib/helper/agent/agent_builtin_commands.dart')
          .readAsStringSync();
      final doc = File('doc/agent.md').readAsStringSync();
      final ids = findCommandIdLiterals(source).toSet();

      // Act
      final stale = undocumentedExceptions
          .where((id) => !ids.contains(id) || documentsCommand(doc, id))
          .toList();

      // Assert
      expect(
        stale,
        isEmpty,
        reason:
            'These exceptions are documented or no longer registered and must '
            'be removed:\n${stale.join('\n')}',
      );
    });
  });
}
