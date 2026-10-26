import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches an `AgentElementType` enum value and its optional `@JsonValue`.
///
/// The enum is declared as `@JsonValue('wire') name,` so a single pattern
/// captures both the Dart identifier and the wire value the protocol sends.
final RegExp elementTypeEntry = RegExp(
  """(?:@JsonValue\\('([^']+)'\\)\\s*)?\\n\\s*([a-zA-Z][a-zA-Z0-9]*),""",
);

/// A single `AgentElementType` value: its Dart name and its wire value.
class ElementTypeEntry {
  /// Creates an entry for [name] with the protocol [wireValue].
  const ElementTypeEntry(this.name, this.wireValue);

  /// The Dart enum identifier, e.g. `textInput`.
  final String name;

  /// The snake_case value sent over the protocol, e.g. `text_input`.
  final String wireValue;

  @override
  String toString() => '$name ($wireValue)';
}

/// Extracts every `AgentElementType` value declared in [source].
List<ElementTypeEntry> findElementTypeEntries(String source) {
  final start = source.indexOf('enum AgentElementType {');
  if (start < 0) return const <ElementTypeEntry>[];
  final end = source.indexOf('\n}', start);
  final body = source.substring(start, end < 0 ? source.length : end);
  return elementTypeEntry
      .allMatches(body)
      .map(
        (match) => ElementTypeEntry(
          match.group(2)!,
          match.group(1) ?? match.group(2)!,
        ),
      )
      .toList(growable: false);
}

/// Returns true when [doc] documents [token] as inline code or a table cell.
bool documentsToken(String doc, String token) => doc.contains('`$token`');

/// Element types that are intentionally not documented in `doc/agent.md`.
///
/// Empty: every enum value currently has a row in the `AgentElementType` table.
const List<String> undocumentedExceptions = <String>[];

void main() {
  group('agent element type documentation guard', () {
    group('findElementTypeEntries', () {
      test('should extract names and wire values', () {
        // Arrange
        const source = '''
enum AgentElementType {
  @JsonValue('button')
  button,

  @JsonValue('text_input')
  textInput,
}
''';

        // Act
        final entries = findElementTypeEntries(source);

        // Assert
        expect(entries.map((entry) => entry.name), ['button', 'textInput']);
        expect(entries.map((entry) => entry.wireValue), [
          'button',
          'text_input',
        ]);
      });

      test('should fall back to the name when no wire value is declared', () {
        // Arrange
        const source = '''
enum AgentElementType {
  other,
}
''';

        // Act
        final entries = findElementTypeEntries(source);

        // Assert
        expect(entries.single.name, 'other');
        expect(entries.single.wireValue, 'other');
      });

      test('should return an empty list when the enum is absent', () {
        // Arrange
        const source = 'enum SomethingElse { a, b }';

        // Act & Assert
        expect(findElementTypeEntries(source), isEmpty);
      });
    });

    group('documentsToken', () {
      test('should match a backticked token', () {
        // Arrange & Act & Assert
        expect(documentsToken('| `textInput` | x |', 'textInput'), isTrue);
      });

      test('should not match a bare token', () {
        // Arrange & Act & Assert
        expect(documentsToken('| textInput | x |', 'textInput'), isFalse);
      });
    });

    test('should document every AgentElementType value in doc/agent.md', () {
      // Arrange
      final source = File('lib/serialized/agent_element_snapshot.dart')
          .readAsStringSync();
      final doc = File('doc/agent.md').readAsStringSync();
      final entries = findElementTypeEntries(source);

      // Act
      final undocumented = entries
          .where((entry) => !undocumentedExceptions.contains(entry.name))
          .where(
            (entry) =>
                !documentsToken(doc, entry.name) ||
                !documentsToken(doc, entry.wireValue),
          )
          .toList();

      // Assert
      expect(
        entries,
        isNotEmpty,
        reason: 'No AgentElementType values were found to check.',
      );
      expect(
        undocumented,
        isEmpty,
        reason:
            'Document every AgentElementType value (name and wire value) in '
            'the doc/agent.md table '
            '(see .github/instructions/agent-readiness.instructions.md §1):\n'
            '${undocumented.join('\n')}',
      );
    });

    test('should keep the undocumented exception list minimal', () {
      // Arrange
      final source = File('lib/serialized/agent_element_snapshot.dart')
          .readAsStringSync();
      final doc = File('doc/agent.md').readAsStringSync();
      final names = findElementTypeEntries(source)
          .map((entry) => entry.name)
          .toSet();

      // Act
      final stale = undocumentedExceptions
          .where((name) => !names.contains(name) || documentsToken(doc, name))
          .toList();

      // Assert
      expect(
        stale,
        isEmpty,
        reason:
            'These exceptions are documented or no longer declared and must be '
            'removed:\n${stale.join('\n')}',
      );
    });
  });
}
