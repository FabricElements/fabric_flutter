---
applyTo: "lib/serialized/**/*.dart"
---

# Serialized Data Model Instructions

These rules govern every data model (DTO / Firestore entity / API contract) in `lib/serialized/`. Models are **data-only**: they carry state across the network and Firestore boundary and must not hold business logic or UI.

## Required pattern

- Annotate the class with `@JsonSerializable(explicitToJson: true)` and declare `part '<file_name>.g.dart';` after the imports.
- Provide a **null-tolerant** `fromJson` factory that accepts a nullable map and falls back to `{}`, plus the matching `toJson`:

  ```dart
  import 'package:json_annotation/json_annotation.dart';

  part 'user_data.g.dart';

  /// Represents a single application user loaded from Firestore.
  ///
  /// Deserialization is null-tolerant so a missing document yields an empty
  /// model rather than throwing.
  @JsonSerializable(explicitToJson: true)
  class UserData {
    /// Creates a [UserData] instance.
    UserData({this.id, this.name, this.roles = const []});

    /// Builds a [UserData] from a JSON [json] map, tolerating `null`.
    factory UserData.fromJson(Map<String, dynamic>? json) =>
        _$UserDataFromJson(json ?? {});

    /// Uniquely identifies the user document.
    final String? id;

    /// Stores the user's display name.
    final String? name;

    /// Lists the role claims granted to the user; empty when none.
    @JsonKey(defaultValue: [])
    final List<String> roles;

    /// Returns this model as a JSON-serializable map.
    Map<String, dynamic> toJson() => _$UserDataToJson(this);
  }
  ```

- Use `@JsonKey` for field **renames**, **default values**, `includeIfNull`, and **custom converters**. Use `FirestoreHelper` (`lib/helper/firestore_helper.dart`) for Firestore `Timestamp` ↔ `DateTime` conversions.
- Document the class, constructor, every field, `fromJson`, and `toJson` with `///` Effective Dart comments (square-bracket references like `[UserData]`; no `@param`/`@returns` tags).

## Backward / forward compatibility (API contract stability)

- **Additive changes only** by default: new fields must be **optional/nullable** or carry a `@JsonKey(defaultValue: …)`, so old payloads still deserialize and new payloads still work on older readers.
- **Never rename or repurpose** an existing serialized key silently. To rename a wire key while keeping the Dart field readable, use `@JsonKey(name: 'wire_name')` rather than changing the field name and breaking the contract.
- **Do not remove** a field that may still exist in stored Firestore documents or in-flight payloads without a migration; prefer deprecating it (keep parsing it) first.
- Keep `fromJson(null)` and empty-map inputs safe — every field must have a sensible default or be nullable.

## Regeneration workflow

- Never hand-edit `*.g.dart`. After **any** model change, regenerate and commit the generated file with the model:

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

## Mandatory tests

- Every model has a mirrored test at `test/serialized/<file_name>_test.dart` covering `fromJson`, `toJson`, a `fromJson → toJson → fromJson` round-trip, and `fromJson(null)` / empty-map tolerance.

**DO NOT**

- ❌ Import Flutter/UI (`package:flutter/...`) or put business logic, formatting, or network calls in a model.
- ❌ Write a `fromJson` that throws on `null` or omits the `?? {}` fallback.
- ❌ Hand-edit, or forget to commit, the generated `*.g.dart` file.
- ❌ Introduce Freezed or another codegen stack — this package uses `json_serializable` only.
- ❌ Rename/remove a serialized key without a compatibility strategy (`@JsonKey(name:)` or migration).
