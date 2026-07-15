# GitHub Copilot Instructions — fabric_flutter

Trust these instructions. Only search the codebase if the information here is incomplete or found to be in error. This file is the **canonical, global source of truth** for conventions in this repository; the scoped rules under `.github/instructions/` refine it for specific file globs.

---

## 1. Project Overview & Tech Stack

### Core Purpose

`fabric_flutter` is a **Flutter package** — a reusable component and architecture library, **not a runnable app** (there is no `main.dart` or `ios/`, `android/`, `web/` platform folder). It ships production-ready, Firebase-powered building blocks for Flutter mobile and web apps:

- 40+ self-contained, reusable UI widgets (auth flows, data tables, pickers, maps, charts, media upload, smart buttons/images/inputs).
- Provider-based `ChangeNotifier` state containers for user/auth, analytics, notifications, and Firestore document/collection/API data.
- A Firebase integration layer (Auth, Firestore, Storage, Functions, Analytics, Messaging, Realtime Database) kept out of the UI.
- Type-safe, JSON-serializable domain models with **null-tolerant** deserialization (`fromJson(null)` → `{}`).
- Stateless utilities: validation, JWT parsing, localization (ISO countries/languages), GSM lookups, regex, formatting, and auth-aware routing.

Consumers wrap their widget tree with `InitApp` (`lib/component/init_app.dart`), which bootstraps the provider tree. `StateUser` listens to `FirebaseAuth.authStateChanges()`, resolves the ID token and custom claims, and loads the Firestore user document; widgets react via `context.watch` / `Provider.of`.

- **License:** BSD 3-Clause.
- **Version:** `pubspec.yaml` is the **single source of truth** for the version (currently `2.3.0`). Never hardcode a version elsewhere without also updating `pubspec.yaml`, the README badge, and `CHANGELOG.md`.
- **SDK:** Dart `^3.12.1`, Flutter stable channel (CI pins `3.44.6`).

### Architectural Map

```
lib/
├── variables.dart      # Global flags (e.g. kIsTest detects the FLUTTER_TEST environment)
├── component/          # UI layer: 40+ self-contained, reusable widgets
│   ├── init_app.dart           # Core provider bootstrap (InitApp / InitAppChild)
│   ├── route_page.dart         # Route-aware page scaffold
│   ├── user_*.dart             # User management widgets (add_update, admin, avatar, chip, dropdown)
│   ├── google_*.dart           # Google Maps / Charts widgets
│   ├── smart_button.dart, smart_image.dart, card_button.dart, input_data.dart, ...
│   └── iframe_minimal*.dart    # Conditional web/native implementations
├── state/              # Business logic / state containers (ChangeNotifier + Provider)
│   ├── state_shared.dart       # Abstract base: pagination, filters, debounce, streams, error/onError
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
│   ├── base_db.dart, user_data.dart, user_status.dart, media_data.dart, logs_data.dart
│   ├── filter_data.dart, table_data.dart, notification_data.dart, place_data.dart, map_data.dart
│   └── chart_preferences.dart, chart_wrapper.dart, gsm_data.dart, iso_data.dart, password_data.dart
├── helper/             # Stateless utilities / repository-style helpers
│   ├── http_request.dart       # HTTP networking (AuthScheme, error/response helpers over package:http)
│   ├── firestore_helper.dart   # Firestore utilities (Timestamp conversions)
│   ├── firebase_storage_helper.dart, media_helper.dart, filter_helper.dart
│   ├── route_helper.dart, redirect_app.dart   # Auth-aware routing
│   ├── provider_helper.dart    # ProviderHelper.isProviderDefined<T>(context)
│   ├── app_global.dart, options.dart, utils.dart, format_data.dart, input_validation.dart
│   ├── enum_data.dart, byte_count_transformer.dart, iso_countries.dart, iso_language.dart
│   ├── gsm.dart, jwt.dart, regex_helper.dart, log_color.dart
│   └── app_localizations_delegate.dart, user_roles.dart, user_roles_firebase.dart
├── placeholder/        # Loading/fallback widgets and default locale data
└── view/               # Full-page composed views (view_auth_page, view_featured, view_hero)

test/                   # Mirrors lib/ structure, files suffixed _test.dart
├── component/          # Widget/semantics tests (e.g. smart_button_semantics_test.dart)
├── helper/             # Tests for lib/helper/*
└── serialized/         # Tests for lib/serialized/*
```

### Core Dependencies

The **README `Core Dependencies` table is the authoritative, versioned list** — keep it in sync with `pubspec.yaml`. Summary of the load-bearing choices:

- **State management:** `provider` (`ChangeNotifier`). **No Riverpod / Bloc / GetX / MobX.**
- **Routing:** Flutter built-in named routes assembled by `RouteHelper` (`lib/helper/route_helper.dart`) into public / authenticated / admin tables. **No go_router / auto_route.**
- **Networking:** `http` wrapped by `lib/helper/http_request.dart`; connectivity via `connectivity_plus`. **No dio / retrofit / chopper.**
- **Backend:** `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage`, `firebase_analytics`, `firebase_messaging`, `firebase_database`, `google_sign_in`.
- **Serialization:** `json_annotation` + dev deps `json_serializable` and `build_runner`. **No Freezed.**
- **Tooling:** `flutter_lints`, `flutter_test`, `integration_test`.

---

## 2. Architecture & Layering Rules

The library follows a **layered architecture** with a state-container pattern (Provider). Respect the dependency direction strictly:

```
component/ , view/   (UI)      ──▶  state/  ──▶  helper/  ──▶  serialized/
   (widgets, thin)                (ChangeNotifier)  (stateless)   (json_annotation only)
```

- **UI is thin.** Widgets in `component/` and `view/` render state and forward user intent. **Do not** put business logic, network calls, Firebase SDK calls, or data transformation inside a widget's `build`. Push that into a `state/` container or a `helper/`.
- **Business logic lives in `state/`.** State classes extend `ChangeNotifier` — or one of the provided bases `StateShared` / `StateDocument` / `StateCollection` / `StateAPI` for data sources — and expose data + `error` + `loading` to the UI.
- **`helper/` is stateless.** Pure functions and repository-style utilities. No `ChangeNotifier`, no widget imports.
- **`serialized/` is data-only.** Models depend on `json_annotation` (and Firestore types where required) and **never** import Flutter/UI or contain business logic.
- **Never call a Firebase SDK directly from a widget.** Route every Firestore/Auth/Storage/Functions/Messaging interaction through a `state/` class or a `helper/` utility.
- **Dependency injection is Provider.** Read state with `context.read` / `context.watch` / `Provider.of`; guard optional providers with `ProviderHelper.isProviderDefined<T>(context)`. Register app-wide state in `InitApp`.
- **Composition over monoliths.** Build large UIs by composing small widgets; accept `VoidCallback` / `ValueChanged<T>` callbacks instead of embedding logic.

---

## 3. Naming Conventions

| Element | Convention | Examples |
|---------|-----------|----------|
| **Files & directories** | `lower_snake_case.dart`, mirrored 1:1 in `test/` with a `_test.dart` suffix | `smart_button.dart` → `test/component/smart_button_semantics_test.dart` |
| **Classes / enums / typedefs** | `UpperCamelCase` | `SmartButton`, `HTTPRequest`, `AuthScheme` |
| **State containers** | `State<Feature>` extending `ChangeNotifier`/`StateShared`/… | `StateUser`, `StateAnalytics`, `StateShared` |
| **Serialized models** | `<Entity>Data` (data-carrying) or descriptive noun | `UserData`, `MediaData`, `PasswordData`, `ChartPreferences` |
| **Generated files** | `<name>.g.dart` — never hand-edited | `user_data.g.dart` |
| **Members & locals** | `lowerCamelCase`; private members prefixed `_` | `formattedCredentials`, `_error`, `_resolveAutomationKey` |
| **Constants** | `lowerCamelCase` (Dart style), not `SCREAMING_CAPS` | `kIsTest`, `defaultLocales` |
| **Booleans** | Prefix with `is` / `has` / `can` / `should` | `isActionable`, `hasError` |
| **Accessibility identifiers** | `[RouteName]_[ContextBlock]_[ComponentType]_[ActionOrId]` (snake, lowercase) | `settings_profile_input_email`, `home_toolbar_button_save` |

**Deliberate exceptions (do not "fix"):** enum values that mirror external protocol tokens use capitalized identifiers with a file-level `// ignore_for_file: constant_identifier_names` (e.g. `AuthScheme.Basic`, `HTTPMethod.GET` in `http_request.dart`). Follow the existing pattern when it maps to an external contract; otherwise use `lowerCamelCase` enum values.

---

## 4. Coding Style & Modern Dart

Lints come from `package:flutter_lints/flutter.yaml` plus `analysis_options.yaml`:

- `prefer_single_quotes: true` — **always single quotes**.
- `avoid_print: true` — **never `print()`**; use `debugPrint()` (colorize via `lib/helper/log_color.dart` when helpful).
- The analyzer **ignores** `undefined_prefixed_name` (conditional web imports) and `use_build_context_synchronously`. It **excludes** platform dirs (`ios/`, `android/`, `windows/`, `macOS/`, `linux/`, `web/`), `build/`, `.dart_tool/`, and generated `*.g.dart` / `*.freezed.dart`.

Style rules:

- **Trailing commas are mandatory** on all multi-line argument/parameter lists so `dart format` wraps deterministically.
- Prefer **immutability**: `const` constructors wherever possible, `final` fields, `StatelessWidget` unless local mutable state is genuinely required.
- Use **modern Dart 3 syntax** where it improves clarity: sound null-safety (no unnecessary `!`), collection-if/for, spreads, `switch` expressions and records/patterns where they read cleanly. Prefer `??` / `?.` / null-aware spreads over manual null checks.
- Keep functions small and single-purpose; extract private helpers (`_name`) rather than growing a method.
- **Do not add new dependencies** unless absolutely necessary — prefer packages already in `pubspec.yaml`, then the Flutter SDK / Material, then first-party `flutter.dev`/`dart.dev` or Flutter Favorite packages.

---

## 5. Error Handling & Logging Standards

**Error propagation (follow the existing convention):**

- Networking helpers in `lib/helper/http_request.dart` **throw a plain `String` message** on failure (e.g. `throw 'error--$statusCode'`), preferring a JSON `message`, then a JSON `errors[].description` list, then the HTTP reason phrase. When adding networking code, follow this pattern rather than inventing new `Exception` subclasses.
- State containers extend `StateShared`, which exposes a settable `error` and an `onError` callback. Set `state.error = message;` to surface failures — this notifies listeners, streams the error, and invokes `onError` (default: `debugPrint(LogColor.error(error))`). **Do not** swallow errors silently; route them through `error`/`onError`.
- Wrap risky calls in `try/catch`, convert to a user-meaningful message, and surface it via the state's `error`. Never leak raw stack traces to the UI.

**Logging:**

- Use `debugPrint()`, never `print()`. Optionally colorize with `LogColor` (`lib/helper/log_color.dart`): `LogColor.error(...)`, etc.
- Wrap verbose/diagnostic logging in `if (kDebugMode) { ... }` so it is stripped from release builds.
- **Never log secrets, tokens, credentials, or full PII.** Log identifiers or status codes, not `Authorization` headers or ID tokens.

---

## 6. Security Guardrails

- **Never commit secrets, API keys, service-account files, or Firebase credentials.** They belong in the consumer app's environment/CI, never in this package.
- **Never log tokens or credentials** (see §5). Treat `Authorization` headers, ID tokens, and custom claims as sensitive.
- **Authorization is enforced server-side.** Client-side role/claim checks (`StateUser`, `user_roles.dart`) are for UX only; assume Firestore Security Rules and Cloud Functions are the real gate.
- **Validate and sanitize input** with `InputValidation` / `regex_helper.dart` before use; never interpolate untrusted input into queries or dynamic code.
- Use `kIsTest` (`lib/variables.dart`) so production code skips real Firebase/platform calls under `FLUTTER_TEST` — tests must never open real connections.

---

## 7. Accessibility & Agent Directives

Interactive components expose a consistent **accessibility + automation** surface that maps directly onto Flutter's `Semantics`. When you add or edit an interactive widget, wire these three optional parameters:

| Parameter | Maps to | Purpose |
|-----------|---------|---------|
| `semanticsLabel` (`String?`) | `Semantics.label` | Human/agent-readable label; falls back to the visible label when `null`. |
| `automationKey` (`String?`) | `Semantics.identifier` | Deterministic test/automation id following `[RouteName]_[ContextBlock]_[ComponentType]_[ActionOrId]`. |
| `semanticHint` (`String?`) | `Semantics.hint` | Extra guidance for screen readers and autonomous agents (e.g. why an action is disabled). |

```dart
return Semantics(
  label: widget.semanticsLabel ?? widget.button.label,
  identifier: widget.automationKey,
  hint: widget.semanticHint,
  enabled: isActionable,
  container: true,
  child: child,
);
```

- All three are strictly nullable; passing `null` gracefully omits that field and preserves native accessibility behavior.
- Pass `hint` **regardless of `enabled` state** so agents can read why a control is disabled.
- Canonical implementations: `smart_button.dart`, `card_button.dart`, `input_data.dart` (which auto-derives `automationKey` from the route + label when none is given). Wrapper widgets (e.g. `UsersDropdown`) forward these to the widget they wrap.
- Every interactive component with these hooks must have a `test/component/<name>_semantics_test.dart` verifying label/identifier/hint appear in the semantics tree.

---

## 8. Serialization (summary — see `.github/instructions/serialized-models.instructions.md`)

- Annotate models with `@JsonSerializable(explicitToJson: true)` and declare `part '<name>.g.dart';`.
- `fromJson` factories accept a **nullable** map and fall back to `{}`:
  ```dart
  factory PasswordData.fromJson(Map<String, dynamic>? json) =>
      _$PasswordDataFromJson(json ?? {});
  ```
- Provide `Map<String, dynamic> toJson() => _$XToJson(this);`.
- Use `@JsonKey` for renames/defaults/converters; use `FirestoreHelper` for `Timestamp` conversions.
- **Regenerate** after any change and commit the `*.g.dart` alongside the model — never hand-edit generated files:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

---

## 9. Testing (summary — see `.github/instructions/tests.instructions.md`)

- Tests live under `test/`, mirroring `lib/` exactly with a `_test.dart` suffix.
- Structure: `group('<ClassName>')` → nested `group`s → `test('should ...')`, each body split into explicit `// Arrange`, `// Act`, `// Assert` sections.
- **No real I/O** — never touch Firebase/Firestore/Storage/HTTP; use in-memory data, canned JSON, fakes/mocks. Production code branches on `kIsTest`.
- Cover model round-trips (`fromJson`→`toJson`→`fromJson`), `fromJson(null)`/empty tolerance, widget behavior (`testWidgets` in a minimal `MaterialApp`), and semantics.
- Add at least one test for every bug fix or feature.

---

## 10. Build, Validation & CI

Run in a fresh checkout, in order:

```bash
flutter pub get                                           # bootstrap (always first)
dart run build_runner build --delete-conflicting-outputs  # only if serialized models changed
flutter analyze                                           # lint — must report no issues
dart format .                                             # formatting (trailing commas drive wrapping)
flutter test                                              # full suite
flutter test test/path/to/file_test.dart                  # single file
flutter test --update-goldens                             # only when a golden's appearance changed intentionally
```

- `package.json` shortcut: `npm run serialize` → `build_runner build --delete-conflicting-outputs` (prefer `dart run build_runner …`).
- **CI:** `.github/workflows/ci.yml` runs on push and PRs to `main`. It sets up Flutter stable (pinned `3.44.6`), then `flutter pub get` → `build_runner build` → `flutter analyze` → `flutter test`. **Analyze and tests must pass.**
- **Pre-commit hooks:** install with `scripts/install-hooks.sh` (see `scripts/README.md`) to auto-format, run `flutter analyze`, and block `print()` before commit.
- Always run `flutter analyze` and `flutter test` after any `lib/` change and confirm both are green before finishing.

---

## 11. Files to Update for a New Feature / Data Entity

Keep these synchronized when introducing a domain feature or entity:

1. `lib/serialized/<entity>.dart` — the `@JsonSerializable` model.
2. `lib/serialized/<entity>.g.dart` — regenerated via `build_runner` (never hand-written).
3. `lib/state/state_<feature>.dart` — state container if the feature carries app state (register in `lib/component/init_app.dart` if app-wide).
4. `lib/helper/<feature>_helper.dart` — supporting stateless logic, if needed.
5. `lib/component/<feature>*.dart` — UI widgets, if the feature has UI (wire the §7 accessibility hooks).
6. `test/serialized/<entity>_test.dart` and/or `test/helper/<feature>_helper_test.dart` (+ `test/component/<name>_semantics_test.dart` for interactive widgets) — mirrored tests, mandatory.
7. `README.md` — update the Architectural Map / Core Dependencies / feature docs.
8. `CHANGELOG.md` and the `version` field in `pubspec.yaml` when preparing a release.

---

## 12. Guardrails & Implementation Rules

These are the load-bearing guardrails. They are cumulative — none may be dropped — and each is refined by the section it references.

- **fabric_flutter first (mandatory):** when creating or editing components and helpers, always use the `fabric_flutter` package as the primary base. Search `lib/component/`, `lib/helper/`, `lib/state/`, and `lib/serialized/` for an existing widget, helper, state class, or model that solves (or can be **extended** to solve) the need before writing anything new. Only if the solution genuinely cannot be built with `fabric_flutter` may you fall back to other options — and then always prefer the approach officially recommended by Flutter (Flutter SDK / Material widgets, first-party `flutter.dev`/`dart.dev` packages, or Flutter Favorite packages) over third-party alternatives.
- **Strict modularity and composition:** widgets in `component/` must be self-contained and reusable; compose small widgets instead of building monoliths. Accept callbacks (`VoidCallback`, `ValueChanged<T>`) for interactions rather than embedding business logic. Keep widgets thin per §2 — no Firebase SDK calls, network requests, or data transformation inside a `build`.
- **Reuse before creating:** before crafting new UI, reuse existing components (`SmartButton`, `SmartImage`, `InputData`, `ContentContainer`, `SectionTitle`, `PaginationContainer`, `Breadcrumbs`, `StatusChip`, etc.), existing helpers (`FormatData`, `InputValidation`, `Utils`, `Options`), and Material theme tokens (`Theme.of(context)`); never hardcode colors, spacing, or text styles when a theme value exists.
- **State access:** obtain state via `provider` (`context.read` / `context.watch` / `Provider.of`); guard optional providers with `ProviderHelper.isProviderDefined<T>(context)`. New app-wide state classes must extend `ChangeNotifier` (or `StateShared`/`StateDocument`/`StateCollection`/`StateAPI` for data sources) and be registered in `InitApp` when they are core.
- **Accessibility & agent directives (mandatory for interactive widgets):** wire `semanticsLabel`, `automationKey`, and `semanticHint` onto `Semantics` as described in §7, and add the mirrored `test/component/<name>_semantics_test.dart`.
- **Error routing:** never swallow errors — surface them through the state's `error`/`onError` (§5) and log with `debugPrint`/`LogColor` under `kDebugMode`. Follow the existing plain-`String` throw convention in networking helpers.
- **No new dependencies** unless absolutely necessary; prefer the packages already in `pubspec.yaml` (see §4 fallback order). Never add Riverpod/Bloc/GetX, go_router, dio, or Freezed.
- **Security (see §6):** never commit secrets, API keys, or Firebase credentials; never log tokens or credentials; treat client-side role/claim checks as UX only — authorization is enforced server-side.
- **Files that must be updated synchronously when declaring a new domain feature or data entity:** follow the full 8-item checklist in §11 (`serialized/` model + regenerated `.g.dart`, `state/` container registered in `InitApp` if app-wide, `helper/`, `component/` UI, mirrored `test/`, `README.md`, and `CHANGELOG.md` + `pubspec.yaml` version on release).
- **Do not edit generated files (`*.g.dart`) or `pubspec.lock` by hand.**
- **Do not remove or weaken existing tests to make changes pass.**

---

## 13. Explicit Do's and Don'ts

**DO**
- ✅ Reuse existing components (`SmartButton`, `SmartImage`, `InputData`, `ContentContainer`, `SectionTitle`, `PaginationContainer`, `Breadcrumbs`, `StatusChip`, …) and helpers (`FormatData`, `InputValidation`, `Utils`, `Options`) before writing anything new.
- ✅ Use `Theme.of(context)` tokens for colors, spacing, and text styles.
- ✅ Keep widgets thin; move logic into `state/` or `helper/`.
- ✅ Document every public **and** private API element with `///` (Effective Dart) — see the documentation instructions.
- ✅ Regenerate `*.g.dart` and commit it with the model.
- ✅ Surface errors through `state.error` / `onError`; log with `debugPrint`/`LogColor` under `kDebugMode`.
- ✅ Wire `semanticsLabel` / `automationKey` / `semanticHint` on interactive widgets.

**DON'T**
- ❌ Call Firebase SDKs, run network requests, or embed business logic inside a widget `build`.
- ❌ Use `print()`, double-quoted strings, or omit trailing commas on multi-line lists.
- ❌ Hardcode colors, spacing, or text styles when a theme token exists.
- ❌ Add Riverpod/Bloc/GetX, go_router, dio, or Freezed — stay within the established stack.
- ❌ Hand-edit `*.g.dart` or `pubspec.lock`.
- ❌ Add UI imports or business logic to `serialized/` models.
- ❌ Log secrets/tokens, commit credentials, or rely on client-side checks for real authorization.
- ❌ Weaken or delete existing tests to make a change pass.
- ❌ Open real network/Firebase connections in tests.

---

## 14. Pull Request & Contribution Workflow

- Follow `CONTRIBUTING.md`: feature branches, an issue per change, at least one test per bug fix or feature, squashed commits where practical.
- Before submitting: `flutter analyze` (clean), `dart format .` (no diffs), `flutter test` (all green), and `build_runner` output up to date if models changed.
- Never commit secrets, API keys, or Firebase credentials.
- Keep `README.md` and these instruction files consistent — if a convention changes, update both.
