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

      testWidgets('should add no semantics node of its own', (
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
        expect(node.label, 'content');
        expect(node.identifier, isEmpty);
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

      testWidgets('should report visibility from the mounted state', (
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
  });
}
