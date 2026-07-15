# fabric_flutter

**Version:** 2.2.5  
**License:** [BSD 3-Clause](LICENSE)

[![CI](https://github.com/FabricElements/fabric_flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/FabricElements/fabric_flutter/actions/workflows/ci.yml)
---

## Project Overview & Core Application

`fabric_flutter` is a **Flutter package** — a reusable component and architecture library, **not a standalone runnable application**. There is no `main.dart` or platform (`ios/`, `android/`, `web/`) folder in this repository; instead, consumer apps depend on the package and compile it as part of their own build. Through its Firebase- and Material-based building blocks, it targets the platforms Flutter itself supports, with first-class support for **mobile (iOS/Android)** and **web** (it ships web-specific plugins such as `google_sign_in_web` and `webview_flutter_wkwebview`/`webview_flutter_android`).

The package provides production-ready, Firebase-powered building blocks:

- **Pre-built UI components** — 41 self-contained, reusable widgets covering authentication flows, data tables, media upload, country/language pickers, Google Maps, charts, smart buttons/images, and inputs.
- **Provider-based state management** — Purpose-built `ChangeNotifier` state containers for user/auth, analytics, notifications, and Firestore document/collection/API data.
- **Firebase integration layer** — Helpers for Auth, Firestore, Cloud Storage, Cloud Functions, Analytics, Messaging, and Realtime Database, kept out of the UI layer.
- **Type-safe data models** — `json_serializable` domain models with null-tolerant deserialization (`fromJson(null)` falls back to `{}`).
- **Developer utilities** — Input validation, JWT parsing, localization (ISO countries/languages), GSM provider lookups, regex helpers, formatting, and auth-aware routing.

**Operational flow:** A consumer app wraps its widget tree with the `InitApp` component (`lib/component/init_app.dart`), which bootstraps the provider tree (`StateGlobal`, `StateUser`, `StateAnalytics`, `StateNotifications`, `StateUsers`, `StateViewAuth`). `StateUser` listens to `FirebaseAuth.authStateChanges()`, resolves the ID token and custom claims, and loads the user document from Firestore; UI widgets then react via `context.watch`/`Provider.of`. Routing is handled by Flutter's built-in named routes assembled by `RouteHelper` into public, authenticated, and admin route tables.

**Requirements:** Dart SDK `^3.12.1` and Flutter (stable channel).

---

## Tech Stack & Architecture Map

### Core Dependencies

Sourced directly from [`pubspec.yaml`](pubspec.yaml).

| Category | Packages |
|----------|----------|
| **SDK** | Dart `^3.12.1`, Flutter (stable channel) |
| **State management** | `provider` ^6.1.5+1 (`ChangeNotifier` — no Riverpod/Bloc/GetX) |
| **Firebase / backend** | `firebase_core` ^4.12.1, `firebase_auth` ^6.5.6, `cloud_firestore` ^6.7.1, `cloud_functions` ^6.3.5, `firebase_storage` ^13.4.5, `firebase_analytics` ^12.4.5, `firebase_messaging` ^16.4.3, `firebase_database` ^12.4.6 |
| **Authentication** | `firebase_auth`, `google_sign_in` ^7.2.0, `google_sign_in_web` ^1.1.3 |
| **Serialization** | `json_annotation` ^4.12.0 (dev: `json_serializable` ^6.14.0, `build_runner` ^2.15.1) |
| **Networking** | `http` ^1.6.0, `connectivity_plus` ^7.3.0 |
| **Media** | `image_picker` ^1.2.3, `file_picker` ^11.0.2, `image` ^4.9.1, `video_player` ^2.13.0, `mime` ^2.0.0, `image_network` ^2.6.0 |
| **Maps & web views** | `google_maps_flutter` ^2.17.1, `webview_flutter` ^4.14.1, `webview_flutter_android` ^4.13.0, `webview_flutter_wkwebview` ^3.26.0, `web` ^1.1.1, `pointer_interceptor` ^0.10.1+2 |
| **Localization & i18n** | `flutter_localizations`, `devicelocale` ^0.9.0, `intl` ^0.20.2, `dlibphonenumber` ^1.1.67 |
| **UI & content** | `google_fonts` ^8.1.0, `cupertino_icons` ^1.0.9, `omni_datetime_picker` ^2.3.2, `flutter_markdown_plus` ^1.0.12, `scrollable_positioned_list` ^0.3.8, `gap` ^3.0.1, `json_explorer` ^0.1.2 |
| **Utilities** | `package_info_plus` ^10.2.1, `url_launcher` ^6.3.2, `collection` ^1.19.1, `ansicolor` ^2.0.3 |
| **Testing & linting** | `flutter_test`, `integration_test`, `flutter_lints` ^6.0.0 |

### Architectural Map

The library is organized into clean, layered directories under `lib/`:

```
lib/
├── variables.dart      # Global flags (e.g. kIsTest detects the FLUTTER_TEST environment)
├── component/          # UI layer: 41 self-contained, reusable widgets
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

### Architecture Layers & Responsibilities

| Layer | Directory | Responsibility |
|-------|-----------|----------------|
| **UI / Presentation** | `component/`, `view/` | Self-contained, reusable widgets and full-page composed views. Accept callbacks (`VoidCallback`, `ValueChanged<T>`); never call Firebase SDKs directly. |
| **State containers** | `state/` | `ChangeNotifier`-based business logic. `StateShared` provides pagination, filters, debounce, and streams; `StateDocument`/`StateCollection`/`StateAPI` back data sources. |
| **Serialization models** | `serialized/` | `@JsonSerializable(explicitToJson: true)` domain entities with null-tolerant `fromJson` and matching `toJson`. Each model has a generated `*.g.dart` twin. |
| **Helpers / Infrastructure** | `helper/` | Stateless utilities: networking, Firestore/Storage helpers, validation, formatting, routing, localization. |

**Layer rules:** `component/` and `view/` depend on `state/` and `helper/`; `state/` depends on `helper/` and `serialized/`; `serialized/` depends only on `json_annotation` (and Firestore types where needed); `helper/` holds stateless logic. **Never call Firebase SDKs directly from widgets** — route through `state/` classes or `helper/` utilities.

### 🔴 Code Generation Notice

> [!CAUTION]
> **Generated `*.g.dart` files must never be edited by hand.** The serialized models in `lib/serialized/` rely on `json_serializable`, which produces a `<model>.g.dart` twin for every `@JsonSerializable` class. This project uses **`json_serializable` only — there is no `freezed`, so no `*.freezed.dart` targets exist.**
>
> Whenever you add, remove, or modify a field in any `lib/serialized/*.dart` model, regenerate the targets and commit the regenerated file alongside the model:
>
> ```bash
> dart run build_runner build --delete-conflicting-outputs
> ```
>
> An equivalent npm shortcut is defined in [`package.json`](package.json):
>
> ```bash
> npm run serialize   # → flutter pub run build_runner build --delete-conflicting-outputs
> ```
>
> The `--delete-conflicting-outputs` flag is required so the generator can safely overwrite stale outputs. Do not hand-edit `*.g.dart` files or `pubspec.lock`.

---

## Getting Started & Local Compilation

Because `fabric_flutter` is a package rather than an app, "compilation" here means resolving dependencies, running code generation, and validating the library locally. There is no `flutter run` target inside this repository; instead, the package is consumed by a host app (which compiles it for mobile/web).

### Prerequisites

- **Flutter SDK** — stable channel. Confirm with `flutter --version`; switch with `flutter channel stable && flutter upgrade` if needed.
- **Dart SDK** — `^3.12.1` (bundled with a recent stable Flutter).
- **Firebase project** — required only by host apps that exercise the Firebase-backed widgets/state; configure Firebase for your target platforms.

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/FabricElements/fabric_flutter.git
   cd fabric_flutter
   ```

2. **Resolve dependencies** (always run first in a fresh checkout)
   ```bash
   flutter pub get
   ```

3. **Run code generation** (only needed if `lib/serialized/` models changed)
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   # or: npm run serialize
   ```

4. **Analyze and format**
   ```bash
   flutter analyze    # must report no issues
   dart format .      # trailing commas drive stable wrapping
   ```

5. **Run the test suite**
   ```bash
   flutter test
   ```

### Using the package in a host app

Add `fabric_flutter` to the host app's `pubspec.yaml`, then wrap the app with `InitApp`:

```dart
void main() {
  runApp(
    const InitApp(
      notifications: true,
      child: MyApp(),
    ),
  );
}
```

The host app is what runs on a device, emulator, or browser via its own `flutter run` (for example `flutter run -d chrome` for web). `InitApp` installs the provider tree so the package's components and state classes are available throughout the app.

---

## Testing, Goldens & Verification Suite

The verification suite is built on `package:flutter_test`. Tests live under the root `test/` directory and **mirror the structure and naming of `lib/`**, suffixed with `_test.dart` (e.g. `lib/helper/jwt.dart` → `test/helper/jwt_test.dart`).

### Running tests

```bash
flutter test                                  # run the full suite
flutter test test/serialized/user_data_test.dart   # run a single file
```

### Conventions

- **Arrange–Act–Assert** — every test body uses explicit `// Arrange`, `// Act`, `// Assert` sections (see `test/serialized/password_data_test.dart`).
- **Structure** — a top-level `group('<ClassName>', …)` per class, nested `group`s per behavior, and descriptive `test('should …')` names.
- **Serialized models** — cover round-trips (`fromJson` → `toJson` → `fromJson`), null/empty tolerance (`fromJson(null)`), and edge cases.
- **Widget tests** — use `testWidgets` with `WidgetTester`, pumping the widget inside a minimal `MaterialApp` scaffold.

### Isolation & mock environments (no live network)

> [!IMPORTANT]
> Tests must **never** open real HTTP connections or touch Firebase/Firestore/Storage or any external service. Use in-memory data, canned JSON maps, and mocked clients only.

Production code exposes the `kIsTest` flag (from `lib/variables.dart`), which detects the `FLUTTER_TEST` environment so Firebase/platform interactions are skipped automatically during tests.

### Golden (visual regression) tests

Golden tests are run through the same `flutter test` runner. When a widget's intended appearance changes, regenerate the reference images with:

```bash
flutter test --update-goldens
```

Run goldens in the same isolated, mock-only manner as the rest of the suite (no live services). Commit updated golden images only when the visual change is intentional and reviewed.

---

## AI-Assisted Engineering Rules

This repository is heavily optimized for AI-assisted workflows using **GitHub Copilot**. Human contributors and AI assistants are held to the **same** standards so generated and hand-written code stay indistinguishable.

> [!IMPORTANT]
> Before editing or generating code, review **[`.github/copilot-instructions.md`](.github/copilot-instructions.md)** — it is the canonical source of truth for conventions. Ensure your AI chat assistant is grounded in that file (and the scoped rules under `.github/instructions/`) so suggestions remain consistent with the codebase.

Key parameters enforced for both humans and AI:

- **Linting** — From `package:flutter_lints/flutter.yaml` plus [`analysis_options.yaml`](analysis_options.yaml): `prefer_single_quotes: true` (always single quotes) and `avoid_print: true` (use `debugPrint()`, optionally colorized via `lib/helper/log_color.dart`). The analyzer ignores `undefined_prefixed_name` for conditional web imports.
- **Trailing commas are mandatory** on all multi-line argument/parameter lists so `dart format` produces stable, readable wrapping.
- **Documentation follows [Effective Dart: Documentation](https://dart.dev/effective-dart/documentation)** for every public **and** private API element:
  - Triple-slash `///` doc comments only — never `/* */` or `//` for API docs.
  - A single-sentence summary that is capitalized, ends with a period, and starts with a third-person verb ("Builds…", "Stores…", "Provides…"), separated from further detail by a blank `///` line.
  - Reference in-scope types and members with **square brackets** (e.g. `[BuildContext]`, `[PasswordData]`, `[stream]`) and literals with backticks (`` `null` ``).
  - No Javadoc-style `@param`/`@returns`/`@throws` tags — weave behavior into prose.
- **fabric_flutter first** — reuse existing components (`SmartButton`, `SmartImage`, `InputData`, `ContentContainer`, …), helpers (`FormatData`, `InputValidation`, `Utils`, `Options`), and theme tokens before writing anything new; only fall back to Flutter-recommended options when the package genuinely cannot solve the need.
- **State access** — obtain state via `provider` (`context.read`/`context.watch`/`Provider.of`); guard optional providers with `ProviderHelper.isProviderDefined<T>(context)`.
- **No new dependencies** unless absolutely necessary; never commit secrets, API keys, or Firebase credentials.

When a new domain feature or data entity is introduced, keep its files synchronized: the `serialized/` model and regenerated `.g.dart`, any `state/` container (registered in `InitApp` if app-wide), supporting `helper/`, `component/` UI, mirrored `test/` files, and this `README.md`.

---

## Contributing Workflow

See [CONTRIBUTING.md](CONTRIBUTING.md) for full details. In summary:

1. Create a feature branch (one issue per change).
2. **Install the pre-commit hooks** (recommended):
   ```bash
   ./scripts/install-hooks.sh
   ```
   The hook runs `dart format` on staged Dart files, `flutter analyze`, a `print()` check (use `debugPrint()`), and a single-quote/documentation check on each `git commit`. Bypass only in emergencies with `git commit --no-verify`.
3. Add or update tests for every bug fix or feature (mandatory).
4. Validate locally — all of these must pass before submitting:
   ```bash
   flutter analyze     # clean
   dart format .       # no diffs
   flutter test        # all green
   dart run build_runner build --delete-conflicting-outputs   # if models changed
   ```

> [!NOTE]
> There are currently **no GitHub Actions CI workflows** in this repository. The required validation is the local sequence above (`flutter analyze` + `flutter test`, plus the pre-commit hooks). Run it before opening a pull request.

When bumping the package version, update the **Version** line at the top of this README, the `version` field in [`pubspec.yaml`](pubspec.yaml), and add a [`CHANGELOG.md`](CHANGELOG.md) entry.

---

## Debug & Development Tips

### Android Google Sign-In issues

If Google Sign-In fails on an Android emulator:

1. Open the host app's `android/` folder in Android Studio.
2. Sync Gradle and resolve any build errors.
3. Verify `applicationId` in `android/app/build.gradle`.
4. Update the Kotlin version to the latest in the Gradle files.
5. Generate SHA-1 and SHA-256 certificates ([instructions](https://developers.google.com/android/guides/client-auth)).
6. Add the fingerprints to the Firebase Console.
7. Re-download `google-services.json`.
8. Clean and rebuild the project.

### Working with locally ignored files

Some configuration files can be ignored on your local checkout without untracking them:

```bash
git update-index --skip-worktree default_values.txt      # stop tracking local changes
git update-index --no-skip-worktree default_values.txt    # resume tracking
git ls-files -v . | grep ^S                               # list skip-worktree files
```

---

## Additional Resources

- **Issues & bugs:** [GitHub Issues](https://github.com/FabricElements/fabric_flutter/issues)
- **Contributing guide:** [CONTRIBUTING.md](CONTRIBUTING.md)
- **Copilot / AI instructions:** [.github/copilot-instructions.md](.github/copilot-instructions.md)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
- **License:** [BSD 3-Clause](LICENSE)
