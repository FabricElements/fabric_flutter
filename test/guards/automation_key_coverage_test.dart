import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips line and block comments so commented-out signatures are ignored.
String stripDartComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// Returns the balanced argument text after the first `(` at or after [from].
String balancedArgs(String source, int from) {
  final open = source.indexOf('(', from);
  if (open == -1) return '';
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') {
      depth++;
    } else if (source[i] == ')') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return source.substring(open + 1);
}

/// Describes one public widget class and its constructor signature.
class WidgetSignature {
  /// Creates a signature record for [className] declared in [path].
  WidgetSignature({
    required this.className,
    required this.path,
    required this.constructorParams,
  });

  /// The public widget class name.
  final String className;

  /// Repository-relative path of the declaring file.
  final String path;

  /// The constructor's parameter list, comments stripped.
  final String constructorParams;
}

/// Returns every public `StatelessWidget` / `StatefulWidget` declared under
/// `lib/component/`, paired with its constructor parameter list.
List<WidgetSignature> scanComponentWidgets() {
  final signatures = <WidgetSignature>[];
  for (final entity in Directory(
    'lib/component',
  ).listSync().whereType<File>()) {
    if (!entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    final source = stripDartComments(entity.readAsStringSync());
    final declared = <String>{};
    final pattern = RegExp(
      r'class\s+([A-Z]\w*)\s+extends\s+(?:StatelessWidget|StatefulWidget)\b',
    );
    for (final match in pattern.allMatches(source)) {
      final className = match.group(1)!;
      if (declared.contains(className)) continue;
      declared.add(className);
      final ctor = RegExp('(?:const\\s+)?\\b$className\\s*\\(')
          .firstMatch(source);
      signatures.add(
        WidgetSignature(
          className: className,
          path: entity.path.replaceAll('\\', '/'),
          constructorParams: ctor == null
              ? ''
              : balancedArgs(source, ctor.start),
        ),
      );
    }
  }
  return signatures;
}

/// Matches a parameter that makes a widget respond to user input.
final RegExp interactiveParam = RegExp(r'\b(?:onPressed|onChanged|onTap)\b');

/// Matches the agent-readiness parameter every interactive widget must accept.
final RegExp automationKeyParam = RegExp(r'\bautomationKey\b');

/// Reviewed exceptions: interactive public widgets that do not yet accept
/// `automationKey`, in the form `path::ClassName`.
///
/// `UserAddUpdate` composes individually agent-ready controls (`InputData`,
/// `SmartButton`) and its `onChanged` is an output notification rather than a
/// user-facing control; adding a key would require deciding which inner control
/// owns it. Tracked here rather than guessed at, so only NEW offenders fail.
const List<String> automationKeyExceptions = <String>[
  'lib/component/user_add_update.dart::UserAddUpdate',
];

void main() {
  group('automationKey coverage guard', () {
    group('scanComponentWidgets', () {
      test('should find public widgets and their constructor params', () {
        // Arrange & Act
        final signatures = scanComponentWidgets();

        // Assert
        expect(signatures, isNotEmpty);
        expect(
          signatures.map((signature) => signature.className),
          contains('SmartButton'),
        );
        expect(
          signatures
              .firstWhere((signature) => signature.className == 'SmartButton')
              .constructorParams,
          contains('automationKey'),
        );
      });

      test('should ignore commented-out signatures', () {
        // Arrange
        const source = '''
// class Fake extends StatelessWidget {
//   const Fake({this.automationKey});
// }
class Real extends StatelessWidget {
  const Real({this.automationKey});
}
''';

        // Act
        final stripped = stripDartComments(source);

        // Assert
        expect(stripped, isNot(contains('Fake')));
        expect(stripped, contains('Real'));
      });
    });

    group('interactive detection', () {
      test('should flag a widget taking onPressed without a key', () {
        // Arrange
        const params = '{super.key, required this.onPressed}';

        // Act & Assert
        expect(interactiveParam.hasMatch(params), isTrue);
        expect(automationKeyParam.hasMatch(params), isFalse);
      });

      test('should accept a widget taking onPressed with a key', () {
        // Arrange
        const params = '{super.key, this.onPressed, this.automationKey}';

        // Act & Assert
        expect(interactiveParam.hasMatch(params), isTrue);
        expect(automationKeyParam.hasMatch(params), isTrue);
      });

      test('should not flag a non-interactive widget', () {
        // Arrange
        const params = '{super.key, required this.child}';

        // Act & Assert
        expect(interactiveParam.hasMatch(params), isFalse);
      });
    });

    test('should have an automationKey on every interactive public widget', () {
      // Arrange
      final violations = <String>[];
      for (final signature in scanComponentWidgets()) {
        if (!interactiveParam.hasMatch(signature.constructorParams)) continue;
        if (automationKeyParam.hasMatch(signature.constructorParams)) continue;
        final key = '${signature.path}::${signature.className}';
        if (automationKeyExceptions.contains(key)) continue;
        violations.add(key);
      }

      // Act & Assert
      expect(
        violations,
        isEmpty,
        reason:
            'Every interactive component must accept an automationKey '
            '(see .github/instructions/agent-readiness.instructions.md §1):\n'
            '${violations.join('\n')}',
      );
    });

    test('should keep the exception list minimal and current', () {
      // Arrange
      final interactiveWithoutKey = scanComponentWidgets()
          .where(
            (signature) =>
                interactiveParam.hasMatch(signature.constructorParams) &&
                !automationKeyParam.hasMatch(signature.constructorParams),
          )
          .map((signature) => '${signature.path}::${signature.className}')
          .toSet();

      // Act
      final stale = automationKeyExceptions
          .where((entry) => !interactiveWithoutKey.contains(entry))
          .toList();

      // Assert
      expect(
        stale,
        isEmpty,
        reason:
            'These exceptions are no longer violations and must be removed:\n'
            '${stale.join('\n')}',
      );
    });
  });
}
