import 'package:fabric_flutter/component/content_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentContainer', () {
    group('spacing', () {
      testWidgets('should default to zero spacing for internal flex children', (
        WidgetTester tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ContentContainer(children: [Text('First'), Text('Second')]),
            ),
          ),
        );

        // Act
        final flex = tester.widget<Flex>(find.byType(Flex));

        // Assert
        expect(flex.spacing, 0);
      });

      testWidgets('should forward explicit spacing to the internal flex', (
        WidgetTester tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ContentContainer(
                spacing: 24,
                children: [Text('First'), Text('Second')],
              ),
            ),
          ),
        );

        // Act
        final flex = tester.widget<Flex>(find.byType(Flex));

        // Assert
        expect(flex.spacing, 24);
      });
    });
  });
}
