import 'package:fabric_flutter/component/input_data.dart';
import 'package:fabric_flutter/helper/agent/agent_element_index.dart';
import 'package:fabric_flutter/helper/options.dart';
import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a minimal [MaterialApp] with no Firebase bootstrap.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  group('InputData agent element', () {
    final index = AgentElementIndex.instance;

    setUp(index.reset);
    tearDown(index.reset);

    testWidgets('should index itself under its automationKey', (
      WidgetTester tester,
    ) async {
      // Arrange
      // Act
      await _pump(
        tester,
        InputData(
          value: 'user@example.com',
          type: InputDataType.email,
          label: 'Email',
          automationKey: 'profile_form_input_email',
          semanticHint: 'Work email address',
          onChanged: (value) {},
        ),
      );

      // Assert
      final snapshot = index.snapshotOf('profile_form_input_email')!;
      expect(snapshot.type, AgentElementType.textInput);
      expect(snapshot.label, 'Email');
      expect(snapshot.hint, 'Work email address');
      expect(snapshot.value, 'user@example.com');
      expect(snapshot.enabled, isTrue);
    });

    testWidgets('should report a disabled input as not enabled', (
      WidgetTester tester,
    ) async {
      // Arrange
      // Act
      await _pump(
        tester,
        InputData(
          value: 'a',
          type: InputDataType.string,
          label: 'Name',
          disabled: true,
          automationKey: 'profile_form_input_name',
          onChanged: (value) {},
        ),
      );

      // Assert
      expect(index.handle('profile_form_input_name')!.enabled, isFalse);
    });

    testWidgets('should apply a value through the setter and notify', (
      WidgetTester tester,
    ) async {
      // Arrange
      Object? changed;
      await _pump(
        tester,
        InputData(
          value: 'before',
          type: InputDataType.string,
          label: 'Name',
          automationKey: 'profile_form_input_name',
          onChanged: (value) => changed = value,
        ),
      );

      // Act
      await index.handle('profile_form_input_name')!.setter!('after');
      await tester.pump();

      // Assert
      expect(changed, 'after');
      expect(index.snapshotOf('profile_form_input_name')!.value, 'after');
    });

    testWidgets('should ignore a set attempt on a disabled input', (
      WidgetTester tester,
    ) async {
      // Arrange
      Object? changed;
      await _pump(
        tester,
        InputData(
          value: 'before',
          type: InputDataType.string,
          label: 'Name',
          disabled: true,
          automationKey: 'profile_form_input_name',
          onChanged: (value) => changed = value,
        ),
      );

      // Act
      await index.handle('profile_form_input_name')!.setter!('after');
      await tester.pump();

      // Assert
      expect(changed, isNull);
    });

    testWidgets('should classify a dropdown and resolve an option by label', (
      WidgetTester tester,
    ) async {
      // Arrange
      Object? changed;
      await _pump(
        tester,
        InputData(
          value: 'a',
          type: InputDataType.dropdown,
          label: 'Plan',
          automationKey: 'billing_form_dropdown_plan',
          options: [
            ButtonOptions(value: 'a', label: 'Basic'),
            ButtonOptions(value: 'b', label: 'Premium'),
          ],
          onChanged: (value) => changed = value,
        ),
      );

      // Act
      await index.handle('billing_form_dropdown_plan')!.setter!('Premium');
      await tester.pump();

      // Assert
      expect(
        index.snapshotOf('billing_form_dropdown_plan')!.type,
        AgentElementType.dropdown,
      );
      expect(changed, 'b');
    });

    testWidgets('should parse a date supplied as an ISO-8601 string', (
      WidgetTester tester,
    ) async {
      // Arrange
      Object? changed;
      await _pump(
        tester,
        InputData(
          value: null,
          type: InputDataType.date,
          label: 'Start',
          automationKey: 'orders_form_date_start',
          onChanged: (value) => changed = value,
        ),
      );

      // Act
      await index.handle('orders_form_date_start')!.setter!(
        '2024-03-05T00:00:00.000',
      );
      await tester.pump();

      // Assert
      expect(changed, DateTime(2024, 3, 5));
      expect(
        DateTime.parse(
          index.snapshotOf('orders_form_date_start')!.value! as String,
        ),
        DateTime(2024, 3, 5).toUtc(),
      );
    });

    testWidgets('should index under the derived key when none is given', (
      WidgetTester tester,
    ) async {
      // Arrange
      // Act
      await _pump(
        tester,
        InputData(
          value: 'a',
          type: InputDataType.string,
          onChanged: (value) {},
        ),
      );

      // Assert
      expect(index.ids, ['root_string_input_string']);
    });

    testWidgets('should remove itself from the index on dispose', (
      WidgetTester tester,
    ) async {
      // Arrange
      await _pump(
        tester,
        InputData(
          value: 'a',
          type: InputDataType.string,
          label: 'Name',
          automationKey: 'profile_form_input_name',
          onChanged: (value) {},
        ),
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // Assert
      expect(index.ids, isEmpty);
    });
  });
}
