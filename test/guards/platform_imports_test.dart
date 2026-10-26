import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Platform libraries that only exist on some of the platforms this package
/// ships to. Importing one unconditionally breaks the other platforms.
const List<String> platformLibraries = <String>[
  'dart:io',
  'dart:html',
  'package:web',
];

/// Matches an `import`/`export` of one of [platformLibraries].
final RegExp platformImport = RegExp(
  """^\\s*(?:import|export)\\s+['"](dart:io|dart:html|package:web)(?:/[^'"]*)?['"]""",
  multiLine: true,
);

/// Matches any quoted file reference inside a directive.
final RegExp quotedTarget = RegExp('''['"]([^'"]+\\.dart)['"]''');

/// Matches the `if (dart.library.x)` clause that makes a directive conditional.
final RegExp conditionalClause = RegExp(
  '''if\\s*\\(\\s*dart\\.library\\.[a-zA-Z0-9_]+\\s*\\)''',
);

/// A file that imports a platform library without a conditional guard.
class PlatformImportViolation {
  /// Creates a violation for [path] importing [library].
  const PlatformImportViolation(this.path, this.library);

  /// Repository-relative path of the offending file.
  final String path;

  /// The platform library it imports.
  final String library;

  @override
  String toString() => '$path imports $library';
}

/// Returns the platform libraries imported by [source].
List<String> findPlatformImports(String source) => platformImport
    .allMatches(source)
    .map((match) => match.group(1)!)
    .toList(growable: false);

/// Returns the file names referenced by conditional imports in [source].
///
/// A directive is conditional when it carries an `if (dart.library.x)` clause;
/// every quoted `.dart` reference in that directive is a conditional target.
List<String> findConditionalTargets(String source) {
  final targets = <String>[];
  for (final directive in source.split(';')) {
    if (!conditionalClause.hasMatch(directive)) continue;
    for (final match in quotedTarget.allMatches(directive)) {
      targets.add(match.group(1)!.split('/').last);
    }
  }
  return targets;
}

/// Files that import a platform library directly and are not conditional
/// import targets.
///
/// Each entry is `path::reason`. Every one of these is a deliberate
/// mobile/desktop-only gate: the import is reached only on platforms where the
/// library exists, and the call site is guarded by `kIsWeb` or by the fact
/// that the enclosing widget is never built on web.
const List<String> platformImportExceptions = <String>[
  // `Platform.environment` is only read when `!kIsWeb`, so the import is never
  // evaluated on web.
  'lib/variables.dart::kIsTest reads Platform.environment behind !kIsWeb',
  'lib/state/state_user.dart::Platform gate behind !kIsWeb',
  'lib/state/state_notifications.dart::Platform gate behind !kIsWeb',
  'lib/view/view_auth_page.dart::Platform gate behind !kIsWeb',
  'lib/component/google_maps_preview.dart::Platform gate behind !kIsWeb',
  // `File` is only constructed from bytes already held in memory on
  // non-web platforms; the web path never reaches this helper.
  'lib/helper/media_helper.dart::File used only on non-web platforms',
];

/// Returns the repository-relative path of every Dart file under [root].
List<String> dartFilesUnder(String root) =>
    Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('.dart') && !path.endsWith('.g.dart'))
        .toList(growable: false);

/// Scans [root] and returns every unguarded platform import.
List<PlatformImportViolation> scanPlatformImports(String root) {
  final files = dartFilesUnder(root);
  final conditionalTargets = <String>{};
  for (final path in files) {
    conditionalTargets.addAll(
      findConditionalTargets(File(path).readAsStringSync()),
    );
  }

  final allowed = platformImportExceptions
      .map((entry) => entry.split('::').first)
      .toSet();

  final violations = <PlatformImportViolation>[];
  for (final path in files) {
    final normalized = path.replaceAll('\\', '/');
    if (allowed.contains(normalized)) continue;
    if (conditionalTargets.contains(normalized.split('/').last)) continue;
    for (final library in findPlatformImports(File(path).readAsStringSync())) {
      violations.add(PlatformImportViolation(normalized, library));
    }
  }
  return violations;
}

void main() {
  group('platform import guard', () {
    group('findPlatformImports', () {
      test('should flag a bare dart:io import', () {
        // Arrange
        const source = "import 'dart:io';\n";

        // Act & Assert
        expect(findPlatformImports(source), ['dart:io']);
      });

      test('should flag a package:web import', () {
        // Arrange
        const source = "import 'package:web/web.dart' as web;\n";

        // Act & Assert
        expect(findPlatformImports(source), ['package:web']);
      });

      test('should ignore non-platform imports', () {
        // Arrange
        const source =
            "import 'dart:async';\nimport 'package:flutter/material.dart';\n";

        // Act & Assert
        expect(findPlatformImports(source), isEmpty);
      });
    });

    group('findConditionalTargets', () {
      test('should extract every target of a conditional import', () {
        // Arrange
        const source = '''
import 'iframe_minimal_native.dart'
    if (dart.library.js_interop) 'iframe_minimal_web.dart';
''';

        // Act & Assert
        expect(findConditionalTargets(source), [
          'iframe_minimal_native.dart',
          'iframe_minimal_web.dart',
        ]);
      });

      test('should return an empty list without a conditional clause', () {
        // Arrange
        const source = "import 'dart:io';\n";

        // Act & Assert
        expect(findConditionalTargets(source), isEmpty);
      });
    });

    test(
      'should not import a platform library without a conditional guard',
      () {
        // Arrange & Act
        final violations = scanPlatformImports('lib');

        // Assert
        expect(
          violations,
          isEmpty,
          reason:
              'Import dart:io / dart:html / package:web only through a '
              'conditional import, or add a justified entry to '
              'platformImportExceptions '
              '(see .github/instructions/agent-readiness.instructions.md §4):\n'
              '${violations.join('\n')}',
        );
      },
    );

    test('should keep the exception list minimal and current', () {
      // Arrange
      final files = dartFilesUnder('lib').toSet();

      // Act
      final stale = platformImportExceptions.where((entry) {
        final parts = entry.split('::');
        if (parts.length != 2 || parts[1].trim().isEmpty) return true;
        if (!files.contains(parts.first)) return true;
        return findPlatformImports(File(parts.first).readAsStringSync())
            .isEmpty;
      }).toList();

      // Assert
      expect(
        stale,
        isEmpty,
        reason:
            'Every exception needs an existing file, a reason, and a real '
            'platform import:\n${stale.join('\n')}',
      );
    });
  });
}
