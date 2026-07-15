---
applyTo: "test/**/*.dart"
---

# Test File Instructions

These rules govern all files under `test/`. The suite runs on `package:flutter_test` via `flutter test`; there is no separate mocking package — use hand-written fakes and in-memory data.

## Frameworks & tools

- **Runner/assertions:** `package:flutter_test/flutter_test.dart` (`test`, `group`, `expect`, matchers, `testWidgets`, `WidgetTester`). Widget tests pump inside a minimal `MaterialApp`.
- **Integration:** `integration_test` is available for end-to-end flows (still no live services).
- **Golden (visual regression):** run through the same `flutter test`; regenerate intentionally-changed baselines with `flutter test --update-goldens` and commit updated images only when the change is reviewed and intentional.
- **Mocking:** prefer small hand-written fakes/stubs and canned JSON. Do **not** add a new mocking dependency without strong justification.

## Layout & structure

- Mirror `lib/` **exactly** and suffix with `_test.dart` (`lib/helper/jwt.dart` → `test/helper/jwt_test.dart`; `lib/component/smart_button.dart` → `test/component/smart_button_semantics_test.dart`).
- Import the unit under test via its **package URI** (`package:fabric_flutter/...`), never a relative path into `lib/`.
- Organize with a top-level `group('<ClassName>', …)`, nested `group`s per method/behavior, and descriptive `test('should …')` names.

## Arrange–Act–Assert (mandatory)

Every test body uses explicit `// Arrange`, `// Act`, `// Assert` sections:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fabric_flutter/serialized/password_data.dart';

void main() {
  group('PasswordData', () {
    group('fromJson', () {
      test('should deserialize current and new passwords', () {
        // Arrange
        final json = <String, dynamic>{'currentPassword': 'a', 'newPassword': 'b'};

        // Act
        final data = PasswordData.fromJson(json);

        // Assert
        expect(data.currentPassword, 'a');
        expect(data.newPassword, 'b');
      });

      test('should tolerate a null payload', () {
        // Arrange & Act
        final data = PasswordData.fromJson(null);

        // Assert
        expect(data, isA<PasswordData>());
      });
    });
  });
}
```

## What to cover

- **Serialized models:** `fromJson`, `toJson`, a `fromJson → toJson → fromJson` round-trip, and `fromJson(null)` / empty-map tolerance.
- **Helpers:** pure-function edge cases (empty, null, boundary, invalid input).
- **Interactive widgets:** a `test/component/<name>_semantics_test.dart` asserting `Semantics` `label` / `identifier` / `hint` are populated from `semanticsLabel` / `automationKey` / `semanticHint` (see `test/component/smart_button_semantics_test.dart`, `input_data_semantics_test.dart`).
- Add at least one test for **every** bug fix or new feature.

## Isolation — no live I/O (hard rule)

> Tests must **never** open real HTTP connections or touch Firebase, Firestore, Storage, or any database/external service.

Use in-memory data, canned JSON maps, fakes, and stubbed clients only. Production code branches on `kIsTest` (`lib/variables.dart`, detects `FLUTTER_TEST`) to skip platform/Firebase calls automatically — rely on that instead of mocking Firebase.

## Style & running

- Single-quoted strings, trailing commas on multi-line calls (matches repo lint rules).
- Run the suite: `flutter test` (single file: `flutter test test/path/to/file_test.dart`). Everything must pass before committing.

**DO NOT**

- ❌ Open real network/Firebase/Storage connections or hit external services.
- ❌ Import the unit under test via a relative `../lib/...` path.
- ❌ Delete or weaken an existing assertion just to make a change pass.
- ❌ Skip the `fromJson(null)` / empty-map case for models, or the semantics assertions for interactive widgets.
- ❌ Commit regenerated golden images for unintended visual changes.
