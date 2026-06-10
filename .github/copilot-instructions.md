# GitHub Copilot Instructions — fabric_flutter

Trust these instructions. Only search the codebase if the information here is incomplete or found to be in error.

---

## 1. Project Overview & Tech Stack

### Core Purpose

`fabric_flutter` (currently **v2.2.2**, BSD 3-Clause license) is a **Flutter package** (a reusable component library, not a runnable app — there is no `main.dart` or platform folders). It provides production-ready, Firebase-powered building blocks for Flutter mobile and web applications:

- 40+ reusable UI widgets (auth flows, data tables, pickers, maps, charts, media upload).
- Provider-based state management for users, auth, analytics, notifications, and Firestore data.
- Firebase integration helpers (Auth, Firestore, Storage, Functions, Analytics, Messaging, Realtime Database).
- Type-safe, JSON-serializable domain models with null-tolerant deserialization.
- Utilities for validation, JWT parsing, localization (ISO countries/languages), GSM lookups, regex, and routing.

Requires **Dart SDK `^3.12.1`** and Flutter (stable channel). The package consumer wraps their app with `InitApp` (`lib/component/init_app.dart`) to bootstrap the provider tree.

### Architectural Map

```
lib/
├── variables.dart      # Global flags (e.g., kIsTest detects FLUTTER_TEST environment)
├── component/          # UI layer: 40+ self-contained, reusable widgets
│   ├── init_app.dart           # Core provider bootstrap (InitApp / InitAppChild)
│   ├── route_page.dart         # Route-aware page scaffold
│   ├── user_*.dart             # User management widgets (admin, avatar, chip, dropdown)
│   ├── google_*.dart           # Google Maps / Charts widgets
│   ├── smart_button.dart, smart_image.dart, input_data.dart, ...
│   └── iframe_minimal*.dart    # Conditional web/native implementations
├── state/              # Business logic / state containers (ChangeNotifier + Provider)
│   ├── state_shared.dart       # Abstract base: pagination, filters, debounce, streams
│   ├── state_api.dart          # HTTP API-backed state (extends StateShared)
│   ├── state_document.dart     # Firestore single-document state
│   ├── state_collection.dart   # Firestore collection state
│   ├── state_global.dart       # App-wide state (connectivity, package info)
│   ├── state_user.dart         # Authenticated user, claims, roles
│   ├── state_users.dart        # User directory state
│   ├── state_analytics.dart    # Firebase Analytics
│   ├── state_notifications.dart# FCM notifications
│   └── state_view_auth.dart    # Auth view state
├── serialized/         # Data models: @JsonSerializable classes + generated *.g.dart pairs
│   ├── user_data.dart / user_data.g.dart
│   ├── media_data.dart, logs_data.dart, filter_data.dart, ... (every model has a .g.dart twin)
├── helper/             # Stateless utilities / repository-style helpers
│   ├── http_request.dart       # HTTP networking (AuthScheme, request helpers over package:http)
│   ├── firestore_helper.dart   # Firestore utilities (Timestamp conversions)
│   ├── firebase_storage_helper.dart, media_helper.dart
│   ├── route_helper.dart       # Auth-aware route table builder (RouteHelper)
│   ├── provider_helper.dart    # ProviderHelper.isProviderDefined<T>(context)
│   ├── options.dart, utils.dart, format_data.dart, input_validation.dart
│   ├── iso_countries.dart, iso_language.dart, gsm.dart, jwt.dart, regex_helper.dart
│   └── app_localizations_delegate.dart, log_color.dart, user_roles*.dart
├── placeholder/        # Loading/fallback widgets and default locale data
└── view/               # Full-page composed views (view_auth_page, view_featured, view_hero)

test/                   # Mirrors lib/ structure, files suffixed _test.dart
├── helper/             # Tests for lib/helper/*
├── serialized/         # Tests for lib/serialized/*
└── *_test.dart         # Component/root-level tests
```

Layer rules: `component/` and `view/` (UI) depend on `state/` and `helper/`; `state/` depends on `helper/` and `serialized/`; `serialized/` depends only on `json_annotation` (and Firestore types where needed); `helper/` holds stateless logic. Never call Firebase SDKs directly from widgets — route through `state/` classes or `helper/` utilities.

### Core Dependencies (actual, from `pubspec.yaml`)

- **State management:** `provider` (^6.1.5+1) with `ChangeNotifier` state classes. No Riverpod/Bloc/GetX.
- **Routing:** Flutter's built-in named routes via `RouteHelper` (`lib/helper/route_helper.dart`), which builds auth-aware route tables (public/authenticated/admin routes). No go_router/auto_route.
- **Networking:** `http` (^1.6.0) wrapped by `lib/helper/http_request.dart`; connectivity via `connectivity_plus`. No dio/retrofit.
- **Backend:** `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage`, `firebase_analytics`, `firebase_messaging`, `firebase_database`, `google_sign_in`.
- **Serialization:** `json_annotation` + dev deps `json_serializable` and `build_runner`.
- **Tooling:** `flutter_lints` (^6.0.0), `flutter_test`, `integration_test`.

---

## 2. Build, Validation & Commands

Always run `flutter pub get` first in a fresh checkout. Then, in this order:

```bash
flutter pub get                                              # bootstrap (always first)
dart run build_runner build --delete-conflicting-outputs     # only if serialized models changed
flutter analyze                                              # lint — must report no issues
dart format .                                                # formatting (trailing commas drive wrapping)
flutter test                                                 # run full unit test suite
flutter test test/path/to/file_test.dart                     # run a single test file
```

- `package.json` defines the serialization shortcut: `npm run serialize` → `flutter pub run build_runner build --delete-conflicting-outputs`.
- There are no GitHub Actions CI workflows in this repository; `flutter analyze` + `flutter test` are the required pre-commit validation.
- Always run `flutter analyze` and `flutter test` after any change to `lib/` and confirm both pass before finishing.

---

## 3. Codebase Conventions & Standards

### Coding Style

- Lints come from `package:flutter_lints/flutter.yaml` plus explicit rules in `analysis_options.yaml`:
  - `prefer_single_quotes: true` — always use single quotes for strings.
  - `avoid_print: true` — never use `print()`; use `debugPrint()` (optionally colorized via `lib/helper/log_color.dart`).
  - Analyzer ignores `undefined_prefixed_name` (needed for conditional web imports).
- **Trailing commas are mandatory** on all multi-line argument/parameter lists so `dart format` produces stable, readable wrapping.
- Prefer immutability: `const` constructors wherever possible, `final` fields, `StatelessWidget` unless local mutable state is required.
- Wrap debug logging in `if (kDebugMode)` checks; never log secrets or tokens.
- Use `kIsTest` (from `lib/variables.dart`) to skip Firebase/platform interactions in test environments.

### Documentation Rules (Effective Dart: Documentation)

Every public **and** private API element (classes, constructors, fields, methods, enums, enum values, top-level functions/variables) must be documented:

- Use **triple-slash `///`** doc comments only — never `/* */` blocks or `//` for API docs.
- Start with a **single-sentence summary** that is capitalized, ends with a period, and starts with a third-person verb (e.g., "Builds…", "Stores…", "Provides…").
- Separate the first sentence from further detail with a **blank `///` line**.
- Reference in-scope types, parameters, and members with **square brackets**, e.g. `[BuildContext]`, `[PasswordData]`, `[stream]`. Use backticks for literals and code (`` `null` ``, `` `Authorization` ``).
- **Do NOT** use Javadoc-style `@param`, `@returns`, `@throws` tags. Weave parameter and return behavior into prose instead.
- Document *why*, not just *what*, for non-obvious behavior (see `lib/state/state_shared.dart` and `lib/helper/route_helper.dart` for canonical examples).
- Doc comments use Markdown; keep lines reasonably short and avoid redundant boilerplate like "This class…".

### Serialization Patterns (`lib/serialized/`)

- Every model is annotated with `@JsonSerializable(explicitToJson: true)` and declares `part '<name>.g.dart';`.
- `fromJson` factories accept a **nullable** map and fall back to an empty map for null tolerance:
  ```dart
  factory PasswordData.fromJson(Map<String, dynamic>? json) =>
      _$PasswordDataFromJson(json ?? {});
  ```
- Provide a matching `Map<String, dynamic> toJson() => _$XToJson(this);`.
- After adding or modifying any model, **always regenerate**:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
  and commit the regenerated `*.g.dart` file alongside the model. Never hand-edit `*.g.dart` files.
- Use `FirestoreHelper` utilities for Firestore `Timestamp` conversions; use `@JsonKey` for renames, defaults, and custom converters.

---

## 4. Guardrails & Implementation Rules

- **fabric_flutter first (mandatory):** when creating or editing components and helpers, always use the `fabric_flutter` package as the primary base. Search `lib/component/`, `lib/helper/`, `lib/state/`, and `lib/serialized/` for an existing widget, helper, state class, or model that solves (or can be extended to solve) the need before writing anything new. Only if the solution genuinely cannot be built with `fabric_flutter` may you fall back to other options — and then always prefer the approach officially recommended by Flutter (Flutter SDK / Material widgets, first-party `flutter.dev`/`dart.dev` packages, or Flutter Favorite packages) over third-party alternatives.
- **Strict modularity and composition:** widgets in `component/` must be self-contained and reusable; compose small widgets instead of building monoliths. Accept callbacks (`VoidCallback`, `ValueChanged<T>`) for interactions rather than embedding business logic.
- **Reuse before creating:** before crafting new UI, reuse existing components (`SmartButton`, `SmartImage`, `InputData`, `ContentContainer`, `SectionTitle`, `PaginationContainer`, `Breadcrumbs`, `StatusChip`, etc.), existing helpers (`FormatData`, `InputValidation`, `Utils`, `Options`), and Material theme tokens (`Theme.of(context)`); never hardcode colors, spacing, or text styles when a theme value exists.
- **State access:** obtain state via `provider` (`context.read` / `context.watch` / `Provider.of`); guard optional providers with `ProviderHelper.isProviderDefined<T>(context)`. New app-wide state classes must extend `ChangeNotifier` (or `StateShared`/`StateDocument`/`StateCollection`/`StateAPI` for data sources) and be registered in `InitApp` when they are core.
- **No new dependencies** unless absolutely necessary; prefer the packages already in `pubspec.yaml`.
- **Files that must be updated synchronously when declaring a new domain feature or data entity:**
  1. `lib/serialized/<entity>.dart` — the `@JsonSerializable` model.
  2. `lib/serialized/<entity>.g.dart` — regenerated via `build_runner` (never hand-written).
  3. `lib/state/state_<feature>.dart` — state container if the feature carries app state (register in `lib/component/init_app.dart` if app-wide).
  4. `lib/helper/<feature>_helper.dart` — supporting stateless logic, if needed.
  5. `lib/component/<feature>*.dart` — UI widgets, if the feature has UI.
  6. `test/serialized/<entity>_test.dart` and/or `test/helper/<feature>_helper_test.dart` — mirrored tests (mandatory).
  7. `README.md` — update the Architectural Map / feature documentation (see §6).
  8. `CHANGELOG.md` and the `version` field in `pubspec.yaml` when preparing a release.
- Do not edit generated files (`*.g.dart`) or `pubspec.lock` by hand.
- Do not remove or weaken existing tests to make changes pass.

---

## 5. Testing Protocols

### Test File Architecture

- All test files live under the root `test/` directory, **mirroring the identical pathing and naming of `lib/`**, suffixed with `_test.dart`:
  - `lib/helper/jwt.dart` → `test/helper/jwt_test.dart`
  - `lib/serialized/password_data.dart` → `test/serialized/password_data_test.dart`
- Use `package:flutter_test/flutter_test.dart`; import the unit under test via the package URI (`package:fabric_flutter/...`).
- Structure: a top-level `group('<ClassName>', ...)` per class, nested `group`s per method/behavior, descriptive `test('should ...')` names.

### Testing Patterns

- **Arrange–Act–Assert:** every test body is structured with explicit `// Arrange`, `// Act`, `// Assert` comment sections (see `test/serialized/password_data_test.dart`).
- **Isolation:** test business logic in isolation. Use fakes/mocks for collaborators; the library exposes `kIsTest` (`lib/variables.dart`) so production code can skip Firebase/platform calls under `FLUTTER_TEST`.
- **Absolute prohibition of real I/O:** tests must never open true HTTP connections, touch Firebase/Firestore/Storage, or hit any database or external service. Use in-memory data, canned JSON maps, and mocked clients only.
- Cover round-trips for serialized models (`fromJson` → `toJson` → `fromJson`), null/empty payload tolerance (`fromJson(null)`), and edge cases.
- Widget tests use `testWidgets` with `WidgetTester`, pumping the widget inside a minimal `MaterialApp` scaffold.
- Run `flutter test` and ensure the entire suite passes before committing; add tests for every bug fix or new feature (required by `CONTRIBUTING.md`).

---

## 6. README & Documentation Maintenance

`README.md` is the canonical onboarding document. Keep it accurate:

- When adding/removing/renaming directories or significant files in `lib/`, update the **Architectural Map** tree in the README.
- When adding, removing, or upgrading dependencies in `pubspec.yaml`, update the **Core Dependencies** table.
- When bumping the package version, update the **Version** badge at the top of the README, `pubspec.yaml`, and add a `CHANGELOG.md` entry.
- When adding new components, state classes, or workflows, document them in the relevant README sections (**Core Workflows & Logic**, **Codebase Best Practices**) with the same tone and table/tree formatting already used.
- Keep README code samples compilable against the current API; update them when public APIs change.
- Follow existing README conventions: Markdown tables for dependency matrices, fenced ` ```dart ` blocks for samples, `---` separators between major sections.

---

## 7. Pull Request & Contribution Workflow

- Follow `CONTRIBUTING.md`: feature branches, an issue per change, at least one test per bug fix or feature, and squashed commits where practical.
- Before submitting: `flutter analyze` (clean), `dart format .` (no diffs), `flutter test` (all green), and `build_runner` output up to date if models changed.
- Never commit secrets, API keys, or Firebase credentials.
