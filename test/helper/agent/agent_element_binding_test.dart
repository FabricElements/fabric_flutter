import 'package:fabric_flutter/helper/agent/agent_element_binding.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [future] to completion by pumping real frames in [step] increments.
///
/// [ScrollReveal.reveal] advances one frame at a time from a post-frame
/// callback, so a plain [WidgetTester.pumpAndSettle] cannot drive it — each
/// pump only produces the single frame the loop is currently waiting for.
Future<T?> _driveFrames<T>(
  WidgetTester tester,
  Future<T> future, {
  Duration step = const Duration(milliseconds: 50),
  int maxFrames = 300,
}) async {
  T? result;
  var completed = false;
  future.then(
    (value) {
      result = value;
      completed = true;
    },
    onError: (_) {
      completed = true;
    },
  );
  for (var i = 0; i < maxFrames && !completed; i++) {
    await tester.pump(step);
  }
  return result;
}

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

    group('reveal', () {
      testWidgets('should scroll an off-screen element into view', (
        WidgetTester tester,
      ) async {
        // Arrange
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final index = AgentElementIndex();
        const viewportHeight = 300.0;
        const itemHeight = 100.0;
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              height: viewportHeight,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    SizedBox(
                      height: itemHeight,
                      child: AgentElement(
                        id: 'top',
                        index: index,
                        child: const Text('Top'),
                      ),
                    ),
                    SizedBox(height: viewportHeight * 2),
                    SizedBox(
                      height: itemHeight,
                      child: AgentElement(
                        id: 'bottom',
                        index: index,
                        child: const Text('Bottom'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(index.contains('bottom'), isTrue);
        expect(scrollController.offset, lessThan(viewportHeight));

        // Act — drive frames to let the reveal loop complete.
        final revealed = await _driveFrames(
          tester,
          index.handle('bottom')!.reveal(),
        );

        // Assert — the bottom element was at ~700–800 px, so the scroll
        // controller must have moved past the viewport height to show it.
        expect(revealed, isTrue);
        expect(scrollController.offset, greaterThan(viewportHeight));
      });

      testWidgets('should return false for an unknown id', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        await tester.pumpWidget(
          MaterialApp(
            home: AgentElement(id: 'a', index: index, child: const SizedBox()),
          ),
        );

        // Assert
        expect(index.handle('bogus'), isNull);
      });
    });

    group('semanticActions', () {
      testWidgets('should expose custom actions in the semantics tree', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          AgentElement(
            id: 'a',
            index: index,
            semanticActions: {'Clear': () {}},
            child: const Text('content', textDirection: TextDirection.ltr),
          ),
        );
        final node = tester.getSemantics(find.text('content'));

        // Assert
        expect(node.identifier, 'a');
        expect(node.label, 'content');
        expect(node.childrenCount, 0);
        expect(node.getSemanticsData().customSemanticsActionIds, hasLength(1));
        // Resolve the action label from the id.
        final actionLabel = CustomSemanticsAction.getAction(
          node.getSemanticsData().customSemanticsActionIds!.first,
        )!.label;
        expect(actionLabel, 'Clear');
        handle.dispose();
      });

      testWidgets('should invoke the callback through the semantics action', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        final handle = tester.ensureSemantics();
        var cleared = false;

        // Act
        await tester.pumpWidget(
          AgentElement(
            id: 'a',
            index: index,
            semanticActions: {'Clear': () => cleared = true},
            child: const Text('content', textDirection: TextDirection.ltr),
          ),
        );
        final node = tester.getSemantics(find.text('content'));
        final actionId = node
            .getSemanticsData()
            .customSemanticsActionIds!
            .first;
        // Invoke the custom action through the semantics owner.
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.customAction,
          actionId,
        );

        // Assert
        expect(cleared, isTrue);
        handle.dispose();
      });

      testWidgets('should keep semantics node count unchanged', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        final handle = tester.ensureSemantics();

        // Act — with actions
        await tester.pumpWidget(
          AgentElement(
            id: 'a',
            index: index,
            semanticActions: {'Clear': () {}},
            child: const Text('content', textDirection: TextDirection.ltr),
          ),
        );
        final nodeWithActions = tester.getSemantics(find.text('content'));
        final childCountWith = nodeWithActions.childrenCount;

        // Act — without actions
        await tester.pumpWidget(
          AgentElement(
            id: 'a',
            index: index,
            child: const Text('content', textDirection: TextDirection.ltr),
          ),
        );
        final nodeWithout = tester.getSemantics(find.text('content'));

        // Assert — same single node, no extra boundary
        expect(nodeWithout.childrenCount, childCountWith);
        expect(nodeWithout.identifier, 'a');
        expect(nodeWithout.label, 'content');
        handle.dispose();
      });

      testWidgets('should add nothing when semanticActions is null', (
        WidgetTester tester,
      ) async {
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
        expect(node.getSemanticsData().customSemanticsActionIds, hasLength(0));
        handle.dispose();
      });

      testWidgets('should add nothing when semanticActions is empty', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        final handle = tester.ensureSemantics();

        // Act
        await tester.pumpWidget(
          AgentElement(
            id: 'a',
            index: index,
            semanticActions: <String, VoidCallback>{},
            child: const Text('content', textDirection: TextDirection.ltr),
          ),
        );
        final node = tester.getSemantics(find.text('content'));

        // Assert
        expect(node.getSemanticsData().customSemanticsActionIds, hasLength(0));
        handle.dispose();
      });

      testWidgets('should list actions in the snapshot', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();

        // Act
        await tester.pumpWidget(
          AgentElement(
            id: 'a',
            index: index,
            semanticActions: {'Clear': () {}, 'Reset': () {}},
            child: const Text('content', textDirection: TextDirection.ltr),
          ),
        );
        final snapshot = index.handle('a')!.snapshot();

        // Assert
        expect(snapshot.actions, containsAll(['Clear', 'Reset']));
        expect(snapshot.actions, hasLength(2));
      });

      testWidgets(
        'should have null actions in snapshot when no actions exist',
        (WidgetTester tester) async {
          // Arrange
          final index = AgentElementIndex();

          // Act
          await tester.pumpWidget(
            AgentElement(
              id: 'a',
              index: index,
              child: const Text('content', textDirection: TextDirection.ltr),
            ),
          );
          final snapshot = index.handle('a')!.snapshot();

          // Assert
          expect(snapshot.actions, isNull);
        },
      );
    });

    group('focus', () {
      testWidgets(
        'should focus an InputData by id via the provided focusNode',
        (WidgetTester tester) async {
          // Arrange
          final index = AgentElementIndex();
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AgentElement(
                  id: 'field',
                  index: index,
                  focusNode: focusNode,
                  child: TextField(focusNode: focusNode),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Act
          final result = index.handle('field')!.requestFocus();
          await tester.pump();

          // Assert
          expect(result, isTrue);
          expect(focusNode.hasFocus, isTrue);
        },
      );

      testWidgets('should return false when no focusable descendant exists', (
        WidgetTester tester,
      ) async {
        // Arrange
        final index = AgentElementIndex();
        // FocusScope.isFirstFocus is true when nothing has focus yet, so
        // focusInDirection returns true (focusing the scope itself). To
        // trigger a false return, we first request focus on a different scope
        // so the empty scope is definitely not first and has no fallback.
        final emptyScopeNode = FocusScopeNode();
        final otherFocusNode = FocusNode();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: FocusScope(
              node: emptyScopeNode,
              child: AgentElement(
                id: 'plain',
                index: index,
                child: const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act — request focus on something outside the scope so the empty
        // scope has no child to pass focus to.
        otherFocusNode.requestFocus();
        final result = index.handle('plain')!.requestFocus();
        await tester.pump();

        // Assert — a SizedBox has no focusable descendants.
        expect(result, isFalse);
        addTearDown(otherFocusNode.dispose);
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
