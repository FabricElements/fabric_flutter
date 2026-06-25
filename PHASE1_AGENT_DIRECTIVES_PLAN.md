# Phase 1 Implementation Plan: Agent Directives (Core UI Library)

## Overview
This document outlines the step-by-step plan to add hidden agent directives via `semanticHint` to the core widgets in `fabric_flutter`. This ensures autonomous vision/chat agents can receive structural, non-visual instructions directly on the components.

## 1. New Constructor Parameters
Update the following core widgets to accept a new optional parameter: `final String? semanticHint;`.
- **SmartButton** (`lib/component/smart_button.dart`)
- **CardButton** (`lib/component/card_button.dart`)
- **InputData** (`lib/component/input_data.dart`)
- **UsersDropdown** (`lib/component/users_dropdown.dart`)

Each widget will have `this.semanticHint,` added to its constructor, documented according to Effective Dart guidelines.
`UsersDropdown` will accept `semanticHint` and forward it to the `InputData` widget it wraps.

## 2. Flutter Semantics Mapping
In the `build` method (or helper methods like `_withSemantics`) of `SmartButton`, `CardButton`, and `InputData`:
Map the incoming `semanticHint` to the `hint` property of the `Semantics` widget.

```dart
return Semantics(
  label: widget.semanticsLabel ?? widget.label,
  identifier: widget.automationKey,
  hint: widget.semanticHint, // New property mapping
  enabled: isActionable, 
  container: true,
  child: child,
);
```

## 3. Fallback Preservation
The `semanticHint` parameter is strictly nullable (`String?`). In Dart, passing `hint: null` to `Semantics` gracefully omits the hint from the accessibility tree, preserving native accessibility behaviors without overriding existing screen reader output. It will work flawlessly alongside `semanticsLabel` (mapped to `label`) and `automationKey` (mapped to `identifier`).

## 4. Component Disabled States
When a component is marked as disabled:
- `SmartButton`: `enabled: isActionable` (where actionable means `path != null` or `onTap != null`).
- `InputData`: `enabled: !widget.disabled`.

The `hint: widget.semanticHint` property will be passed to `Semantics` *regardless* of the `enabled` state. This ensures that agents can read the `hint` (e.g., "This button is disabled because the user lacks permissions") even when `enabled: false`.

## 5. Widget Test Update
An updated Flutter widget test template to verify `semanticHint`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fabric_flutter/component/smart_button.dart';

void main() {
  testWidgets('SmartButton includes semanticHint in the accessibility tree', (WidgetTester tester) async {
    // Arrange
    const testHint = 'Agent Directive: Proceed to checkout';
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartButton(
            button: ButtonOptions(label: 'Checkout'),
            semanticHint: testHint,
          ),
        ),
      ),
    );

    // Act
    final Finder buttonFinder = find.byType(SmartButton);
    final SemanticsNode semantics = tester.getSemantics(buttonFinder);

    // Assert
    expect(semantics.hint, testHint);
  });
}
```
