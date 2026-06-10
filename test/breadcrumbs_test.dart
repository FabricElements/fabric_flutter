import 'package:fabric_flutter/component/breadcrumbs.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Define widget for testing
  final buttons = [
    ButtonOptions(
      icon: Icons.home,
      label: 'Home',
      onTap: () {}, // Make it clickable so it renders as ActionChip
    ),
    ButtonOptions(
      label: 'Button Label',
      onTap: () {}, // Make it clickable
    )
  ];
  final widget = MaterialApp(
    home: Scaffold(
      body: Breadcrumbs(
        buttons: buttons,
      ),
    ),
  );

  /// Tests
  testWidgets('find widget with text', (WidgetTester tester) async {
    await tester.pumpWidget(widget);
    expect(find.widgetWithText(ActionChip, 'Button Label'), findsOneWidget);
  });

  testWidgets('find widget with icon', (WidgetTester tester) async {
    await tester.pumpWidget(widget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
