import 'package:fabric_flutter/serialized/agent_element_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentElementSnapshot', () {
    group('fromJson', () {
      test('should deserialize every field', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'settings_profile_input_email',
          'type': 'text_input',
          'label': 'Email',
          'hint': 'Enter a valid email address',
          'value': 'user@example.com',
          'enabled': false,
          'visible': false,
        };

        // Act
        final snapshot = AgentElementSnapshot.fromJson(json);

        // Assert
        expect(snapshot.id, 'settings_profile_input_email');
        expect(snapshot.type, AgentElementType.textInput);
        expect(snapshot.label, 'Email');
        expect(snapshot.hint, 'Enter a valid email address');
        expect(snapshot.value, 'user@example.com');
        expect(snapshot.enabled, isFalse);
        expect(snapshot.visible, isFalse);
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final snapshot = AgentElementSnapshot.fromJson(null);

        // Assert
        expect(snapshot.id, '');
        expect(snapshot.type, AgentElementType.other);
        expect(snapshot.enabled, isTrue);
        expect(snapshot.visible, isTrue);
        expect(snapshot.value, isNull);
      });
    });

    group('toJson', () {
      test('should round-trip without losing data', () {
        // Arrange
        final snapshot = AgentElementSnapshot(
          id: 'home_toolbar_button_save',
          type: AgentElementType.button,
          label: 'Save',
        );

        // Act
        final restored = AgentElementSnapshot.fromJson(
          AgentElementSnapshot.fromJson(snapshot.toJson()).toJson(),
        );

        // Assert
        expect(restored.id, 'home_toolbar_button_save');
        expect(restored.type, AgentElementType.button);
        expect(restored.label, 'Save');
      });
    });
  });
}
