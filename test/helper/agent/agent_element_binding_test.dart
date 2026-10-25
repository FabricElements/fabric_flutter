import 'package:fabric_flutter/helper/agent/agent_element_binding.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentElement', () {
    group('lifecycle', () {
      testWidgets('should register on mount and unregister on dispose', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: AgentElement(
              id: 'home_toolbar_button_save',
              type: AgentElementType.button,
              label: 'Save',
              hint: 'Saves the form',
              index: index,
              child: const SizedBox(),
            ),
          ),
        );

        // Assert
        expect(index.contains('home_toolbar_button_save'), isTrue);
        expect(
          index.handle('home_toolbar_button_save')?.hint,
          'Saves the form',
        );

        // Act
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Assert
        expect(index.length, 0);
      });

      testWidgets('should register nothing when the id is null', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: AgentElement(index: index, child: const SizedBox()),
          ),
        );

        // Assert
        expect(index.length, 0);
      });

      testWidgets('should refresh the indexed entry when the widget rebuilds', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        Widget build(String label) => MaterialApp(
          home: AgentElement(
            id: 'a',
            label: label,
            index: index,
            child: const SizedBox(),
          ),
        );
        await tester.pumpWidget(build('first'));

        // Act
        await tester.pumpWidget(build('second'));

        // Assert
        expect(index.length, 1);
        expect(index.handle('a')?.label, 'second');
      });

      testWidgets('should re-register under a new id', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        Widget build(String id) => MaterialApp(
          home: AgentElement(id: id, index: index, child: const SizedBox()),
        );
        await tester.pumpWidget(build('first'));

        // Act
        await tester.pumpWidget(build('second'));

        // Assert
        expect(index.contains('first'), isFalse);
        expect(index.contains('second'), isTrue);
        expect(index.length, 1);
      });
    });

    group('rendering', () {
      testWidgets('should return the child unchanged', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        const child = Text('content', textDirection: TextDirection.ltr);

        // Act
        await tester.pumpWidget(
          AgentElement(id: 'a', index: index, child: child),
        );

        // Assert
        expect(find.text('content'), findsOneWidget);
        expect(
          tester.widget<AgentElement>(find.byType(AgentElement)).child,
          same(child),
        );
      });

      testWidgets(
        'should merge the identifier into the child node without adding a boundary',
        (WidgetTester tester) async {
          // Arrange
          final index = AgentElementIndex();
          final handle = tester.ensureSemantics();

          // Act
          await tester.pumpWidget(
            AgentElement(
              id: 'a',
              index: index,
              child: const Text('content', textDirection: TextDirection.ltr),
            ),
          );
          final node = tester.getSemantics(find.text('content'));

          // Assert
          // The identifier folds into the child's single node: the label is
          // preserved, the identifier is applied, and no extra boundary node is
          // introduced (a bare Text contributes exactly one leaf node).
          expect(node.label, 'content');
          expect(node.identifier, 'a');
          expect(node.childrenCount, 0);
          handle.dispose();
        },
      );

      testWidgets('should apply no identifier when the id is null', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          AgentElement(
            index: index,
            child: const Text('content', textDirection: TextDirection.ltr),
          ),
        );
        final node = tester.getSemantics(find.text('content'));

        // Assert
        expect(node.label, 'content');
        expect(node.identifier, isEmpty);
        expect(index.length, 0);
        handle.dispose();
      });
    });

    group('activation', () {
      testWidgets('should expose an activator that drives the widget', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        var taps = 0;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: AgentElement(
              id: 'a',
              index: index,
              activator: () => taps++,
              child: const SizedBox(),
            ),
          ),
        );
        await index.handle('a')?.activator?.call();

        // Assert
        expect(taps, 1);
      });

      testWidgets('should report a current route element as visible', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: AgentElement(id: 'a', index: index, child: const SizedBox()),
          ),
        );

        // Assert
        expect(index.handle('a')?.visible, isTrue);
      });
    });

    group('visibility', () {
      /// Runs [body] with `debugPrint` captured into a list.
      ///
      /// The swap is scoped to the body rather than a `setUp`/`tearDown` pair
      /// because `testWidgets` asserts that no foundation debug variable is
      /// still overridden when the body returns, which runs before `tearDown`.
      Future<void> withCapturedLogs(
        Future<void> Function(List<String> logs) body,
      ) async {
        final logs = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          logs.add(message ?? '');
        };
        try {
          await body(logs);
        } finally {
          debugPrint = originalDebugPrint;
        }
      }

      testWidgets('should report a covered route element as invisible', (
        WidgetTester tester,
      ) async {
        await withCapturedLogs((logs) async {
          // Arrange
          final index = AgentElementIndex();
          final navigatorKey = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigatorKey,
              home: AgentElement(
                id: 'a',
                index: index,
                child: const SizedBox(),
              ),
            ),
          );
          final covered = index.handle('a')!;
          expect(covered.visible, isTrue);

          // Act
          navigatorKey.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AgentElement(id: 'a', index: index, child: const SizedBox()),
            ),
          );
          await tester.pumpAndSettle();

          // Assert
          expect(covered.visible, isFalse);
          expect(index.handle('a')?.visible, isTrue);
          expect(logs.where((log) => log.contains('duplicate')), isEmpty);
        });
      });

      testWidgets('should report a muted subtree as invisible', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: TickerMode(
              enabled: false,
              child: AgentElement(
                id: 'a',
                index: index,
                child: const SizedBox(),
              ),
            ),
          ),
        );

        // Assert
        expect(index.handle('a')?.visible, isFalse);
      });

      testWidgets('should warn when two visible elements share a key', (
        WidgetTester tester,
      ) async {
        await withCapturedLogs((logs) async {
          // Arrange
          final index = AgentElementIndex();

          // Act
          await tester.pumpWidget(
            MaterialApp(
              home: Column(
                children: [
                  AgentElement(id: 'a', index: index, child: const SizedBox()),
                  AgentElement(id: 'a', index: index, child: const SizedBox()),
                ],
              ),
            ),
          );
          await tester.pump();

          // Assert
          expect(
            logs.where((log) => log.contains('duplicate automationKey "a"')),
            hasLength(1),
          );
        });
      });

      testWidgets('should not warn when a covered element shares a key', (
        WidgetTester tester,
      ) async {
        await withCapturedLogs((logs) async {
          // Arrange
          final index = AgentElementIndex();
          final navigatorKey = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigatorKey,
              home: AgentElement(
                id: 'a',
                index: index,
                child: const SizedBox(),
              ),
            ),
          );

          // Act
          navigatorKey.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AgentElement(id: 'a', index: index, child: const SizedBox()),
            ),
          );
          await tester.pumpAndSettle();

          // Assert
          expect(logs.where((log) => log.contains('duplicate')), isEmpty);
        });
      });
    });
  });
}
