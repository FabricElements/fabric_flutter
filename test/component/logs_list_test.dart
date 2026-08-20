import 'package:fabric_flutter/component/logs_list.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:fabric_flutter/serialized/logs_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Collects every [TextSpan] in [root] into a flat list for inspection.
List<TextSpan> _flatten(InlineSpan root) {
  final spans = <TextSpan>[];
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      spans.add(span);
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
    }
  }

  visit(root);
  return spans;
}

void main() {
  group('LogsList', () {
    testWidgets('should render an empty box when there are no logs', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LogsList(logs: [])),
        ),
      );

      // Assert
      expect(find.byType(RichText), findsNothing);
    });

    testWidgets('should highlight brace-marked segments in a log entry', (
      tester,
    ) async {
      // Arrange
      final logs = [
        LogsData(
          id: '1',
          text: 'User {updated} the record',
          timestamp: DateTime(2024, 1, 1, 12),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LogsList(logs: logs)),
        ),
      );

      // Assert
      final spans = find
          .byType(RichText)
          .evaluate()
          .map((e) => (e.widget as RichText).text)
          .expand(_flatten)
          .toList();
      final emphasis = spans.firstWhere(
        (span) => span.text?.trim() == 'updated',
        orElse: () => const TextSpan(),
      );
      expect(emphasis.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('should render the entry timestamp with the shared formatter', (
      tester,
    ) async {
      // Arrange
      final timestamp = DateTime(2024, 1, 2, 15, 30);
      final logs = [
        LogsData(id: '1', text: 'A log line', timestamp: timestamp),
      ];
      final expected = DateFormat.yMd().add_jm().format(timestamp);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LogsList(logs: logs)),
        ),
      );

      // Assert
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('passes a non-null id to an action when the entry has none', (
      tester,
    ) async {
      // Arrange: an entry without an id, so LogsList must synthesize one.
      dynamic tappedId;
      final logs = [
        LogsData(text: 'A log line', timestamp: DateTime(2024, 1, 3, 9)),
      ];
      final actions = [
        ButtonOptions(label: 'Remove', onTap: (dynamic id) => tappedId = id),
      ];

      // Act: open the popup menu and tap the action.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogsList(logs: logs, actions: actions),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // Assert
      expect(tappedId, isNotNull);
      expect(tappedId, isA<String>());
    });
  });
}
