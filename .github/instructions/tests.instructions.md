---
applyTo: "test/**/*.dart"
---

# Test File Instructions

These rules apply to all test files under `test/`.

- Mirror the `lib/` directory structure exactly and suffix files with `_test.dart` (e.g., `lib/helper/jwt.dart` → `test/helper/jwt_test.dart`).
- Import `package:flutter_test/flutter_test.dart` and the unit under test via its package URI (`package:fabric_flutter/...`), never via relative paths into `lib/`.
- Organize tests with a top-level `group('<ClassName>', ...)`, nested `group`s per method or behavior, and descriptive `test('should ...')` names.
- Structure every test body with explicit Arrange–Act–Assert sections:

  ```dart
  test('should deserialize current and new passwords', () {
    // Arrange
    final json = <String, dynamic>{'currentPassword': 'a', 'newPassword': 'b'};

    // Act
    final data = PasswordData.fromJson(json);

    // Assert
    expect(data.currentPassword, 'a');
  });
  ```

- **Never** open real HTTP connections or touch Firebase, Firestore, Storage, or any database/external service. Use in-memory data, canned JSON maps, fakes, and mocked clients only. Production code can branch on `kIsTest` (`lib/variables.dart`) to skip platform calls under `FLUTTER_TEST`.
- For widget tests, use `testWidgets` with `WidgetTester` and pump the widget inside a minimal `MaterialApp`.
- For serialized models, always cover `fromJson`/`toJson` round-trips, `fromJson(null)`, and empty-map tolerance.
- Use single quotes for strings and trailing commas on multi-line calls, matching the repository lint rules.
- Run the suite with `flutter test` (single file: `flutter test test/path/to/file_test.dart`) and ensure everything passes before committing.
