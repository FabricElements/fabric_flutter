---
applyTo: "lib/serialized/**/*.dart"
---

# Serialized Data Model Instructions

These rules apply to all data models in `lib/serialized/`.

- Annotate every model class with `@JsonSerializable(explicitToJson: true)` and declare `part '<file_name>.g.dart';` after the imports.
- `fromJson` factories must accept a **nullable** map and fall back to an empty map so deserialization is null-tolerant:

  ```dart
  factory MyModel.fromJson(Map<String, dynamic>? json) =>
      _$MyModelFromJson(json ?? {});
  ```

- Always provide the matching serializer: `Map<String, dynamic> toJson() => _$MyModelToJson(this);`.
- Use `@JsonKey` for field renames, default values, `includeIfNull`, and custom converters. Use `FirestoreHelper` utilities (`lib/helper/firestore_helper.dart`) for Firestore `Timestamp` conversions.
- Never hand-edit `*.g.dart` files. After any model change, regenerate with:

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

  and commit the regenerated `*.g.dart` file together with the model.
- Document the class, every field, the constructor, `fromJson`, and `toJson` with `///` Effective Dart doc comments (square-bracket references like `[MyModel]`, no `@param`/`@returns` tags).
- Keep models free of business logic and Flutter UI imports; they may depend on `json_annotation` and, where required, Firestore types only.
- Every model must have a mirrored test at `test/serialized/<file_name>_test.dart` covering `fromJson`, `toJson`, round-trips, and `fromJson(null)`/empty payload tolerance.
