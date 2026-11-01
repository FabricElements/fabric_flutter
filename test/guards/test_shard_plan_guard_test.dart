import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards `tool/test_shards.json`, the file-level CI shard plan.
///
/// CI used to shard by *test case*, so every job compiled nearly the whole
/// suite. The plan now assigns whole files to a fixed number of groups, which
/// only stays correct while the plan and the test tree on disk agree. These
/// assertions are the mechanism that keeps them in agreement: adding a test
/// file without regenerating the plan fails here, before it can silently go
/// unrun.
void main() {
  const String planPath = 'tool/test_shards.json';
  const String weightsPath = 'tool/test_shard_weights.json';

  /// The repository-relative paths of every `*_test.dart` file on disk.
  List<String> discoverTestFiles() {
    final Directory root = Directory('${Directory.current.path}/test');
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('_test.dart'))
        .map((path) => path.substring(path.indexOf('/test/') + 1))
        .toList()
      ..sort();
  }

  /// Whether a test file is tagged to run only in a real browser.
  bool runsInBrowser(String path) {
    final String source = File('${Directory.current.path}/$path')
        .readAsStringSync();
    return RegExp(r"@TestOn\(\s*'browser'").hasMatch(source);
  }

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File('${Directory.current.path}/$path').readAsStringSync())
          as Map<String, dynamic>;

  /// The repository-relative paths named by the plan, in plan order.
  List<String> plannedFiles(Map<String, dynamic> plan) => <String>[
    for (final dynamic entry in plan['include'] as List<dynamic>)
      ...(entry as Map<String, dynamic>)['files'] as List<dynamic>,
  ].cast<String>();

  group('tool/test_shards.json', () {
    test('should parse as a GitHub Actions matrix with one entry per group', () {
      // Arrange
      final Map<String, dynamic> plan = readJson(planPath);

      // Act
      final List<dynamic> include = plan['include'] as List<dynamic>;

      // Assert
      expect(
        include,
        isNotEmpty,
        reason: 'A plan with no groups would run no tests at all.',
      );
      expect(
        include.length,
        plan['count'],
        reason:
            'The declared group count and the matrix entries disagree. Run '
            '`dart run tool/generate_test_shards.dart` and commit the result.',
      );
      for (final dynamic entry in include) {
        final Map<String, dynamic> group = entry as Map<String, dynamic>;
        expect(
          group['files'],
          isA<List<dynamic>>().having((files) => files, 'files', isNotEmpty),
          reason:
              'Group ${group['index']} has no files. Run '
              '`dart run tool/generate_test_shards.dart` and commit the result.',
        );
      }
    });

    test('should assign every test file exactly once', () {
      // Arrange
      final List<String> onDisk = discoverTestFiles();
      final List<String> planned = plannedFiles(readJson(planPath));
      final Set<String> browserTagged = onDisk
          .where(runsInBrowser)
          .toSet();

      // Act
      final Set<String> plannedSet = planned.toSet();

      // Assert
      // This is the "never drop a test" invariant. A file the plan does not
      // mention is a file CI never runs, and nothing else would notice.
      expect(
        plannedSet.difference(onDisk.toSet()),
        isEmpty,
        reason:
            'The plan names files that do not exist on disk. Run '
            '`dart run tool/generate_test_shards.dart` and commit the result.',
      );
      expect(
        onDisk.toSet().difference(plannedSet),
        browserTagged,
        reason:
            'The plan must cover every test file except the browser-tagged '
            'ones, which a plain `flutter test` skips. Run '
            '`dart run tool/generate_test_shards.dart` and commit the result.',
      );
      expect(
        plannedSet.length,
        planned.length,
        reason:
            'A file is assigned to more than one group, so CI runs it twice '
            'and the group weights are wrong. Run '
            '`dart run tool/generate_test_shards.dart` and commit the result.',
      );
    });

    test('should keep browser-tagged tests out of every group', () {
      // Arrange
      final List<String> planned = plannedFiles(readJson(planPath));
      final Set<String> browserTagged = discoverTestFiles()
          .where(runsInBrowser)
          .toSet();

      // Act
      final Set<String> overlap = planned.toSet().intersection(browserTagged);

      // Assert
      // A browser-tagged file runs under chrome in its own job. A group that
      // also listed it would run it a second time in a plain `flutter test`
      // process where its `@TestOn` tag silently skips it.
      expect(
        overlap,
        isEmpty,
        reason:
            '$overlap is tagged `@TestOn(\'browser\')`, so it must not be in '
            'the shard plan. Run `dart run tool/generate_test_shards.dart` and '
            'commit the result.',
      );
    });

    test('should weight every planned file', () {
      // Arrange
      final Map<String, dynamic> plan = readJson(planPath);
      final Map<String, dynamic> weights = readJson(weightsPath);
      final Map<String, dynamic> measured =
          weights['weights'] as Map<String, dynamic>;

      // Act
      final List<String> unweighted = plannedFiles(plan)
          .where((path) => !measured.containsKey(path))
          .toList();

      // Assert
      expect(
        unweighted,
        isEmpty,
        reason:
            'A planned file has no measured weight, so the balancing is '
            'working from a placeholder. Re-measure and run '
            '`dart run tool/generate_test_shards.dart --from-report <report>` '
            'with the refreshed weights, then commit the result.',
      );
    });

    test('should keep the group weights within a balanced spread', () {
      // Arrange
      final Map<String, dynamic> plan = readJson(planPath);

      // Act
      final List<int> weights = <int>[
        for (final dynamic entry in plan['include'] as List<dynamic>)
          (entry as Map<String, dynamic>)['weight_ms'] as int,
      ];

      // Assert
      // The whole point of the plan is a level critical path. Group weights
      // measured from real per-file costs balance to a few percent; anything
      // much worse means the plan was not produced by the generator.
      final int heaviest = weights.reduce((a, b) => a > b ? a : b);
      final int lightest = weights.reduce((a, b) => a < b ? a : b);
      final double spread = (heaviest - lightest) / heaviest;
      expect(
        spread,
        lessThan(0.05),
        reason:
            'The heaviest group is ${(spread * 100).toStringAsFixed(1)}% '
            'heavier than the lightest, so the slowest shard still sets the '
            'wall clock. Run `dart run tool/generate_test_shards.dart` and '
            'commit the result.',
      );
    });
  });
}
