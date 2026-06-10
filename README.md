# fabric_flutter

**Version:** 2.2.2  
**License:** [BSD 3-Clause](LICENSE)

---

## Project Overview & Value Proposition

`fabric_flutter` is a comprehensive Flutter component library and architectural framework that accelerates development of production-ready, Firebase-powered mobile and web applications. It provides:

- **Pre-built, Production-Ready Components:** A rich collection of UI widgets including authentication flows, data tables, image uploaders, country/language pickers, Google Maps integration, charts, and more.
- **Unified State Management:** Provider-based state architecture with purpose-built state classes for user authentication, analytics, notifications, and Firestore document/collection management.
- **Firebase Integration Layer:** Streamlined helpers for Firebase Auth, Firestore, Cloud Storage, Cloud Functions, Analytics, and Messaging.
- **Type-Safe Data Models:** JSON-serializable domain models (`user_data`, `media_data`, `logs_data`, etc.) with null-tolerant deserialization and automated code generation.
- **Developer-Friendly Utilities:** Input validation, JWT parsing, localization support (ISO countries/languages), GSM provider lookups, regex helpers, and more.

**Target Use Case:** Ideal for teams building enterprise or consumer-facing applications that need robust authentication, real-time data synchronization, cloud storage, and analytics out of the box.

---

## Tech Stack & Architecture

### Core Dependencies

| Category | Technologies |
|----------|-------------|
| **Framework** | Flutter ^3.44.1, Dart SDK ^3.12.1 |
| **State Management** | `provider` (v6.1.5+1) |
| **Backend Services** | Firebase (Auth, Firestore, Functions, Storage, Analytics, Messaging, Database) |
| **Authentication** | `firebase_auth`, `google_sign_in` |
| **Data Serialization** | `json_annotation`, `json_serializable`, `build_runner` |
| **HTTP & Networking** | `http`, `connectivity_plus` |
| **Media Handling** | `image_picker`, `file_picker`, `image`, `video_player` |
| **Maps & Location** | `google_maps_flutter` |
| **Localization** | `flutter_localizations`, `devicelocale`, `intl` |
| **UI Components** | `google_fonts`, `cupertino_icons`, `omni_datetime_picker`, `flutter_markdown_plus`, `webview_flutter`, `scrollable_positioned_list` |
| **Utilities** | `package_info_plus`, `url_launcher`, `mime`, `universal_html`, `dlibphonenumber` |
| **Testing & Linting** | `flutter_test`, `integration_test`, `flutter_lints` |

### Architectural Map

The codebase is organized into a clean, layered architecture:

```
lib/
├── component/          # 40+ reusable UI widgets
│   ├── alert_data.dart
│   ├── init_app.dart   # Core provider bootstrap widget
│   ├── route_page.dart
│   ├── smart_button.dart
│   ├── smart_image.dart
│   ├── user_*.dart     # User management components
│   ├── google_*.dart   # Google Maps/Charts components
│   ├── upload_*.dart   # Media upload components
│   └── ...             # Tables, filters, pickers, inputs, etc.
│
├── state/              # Provider-based state management
│   ├── state_global.dart        # App-wide state (connectivity, package info)
│   ├── state_user.dart          # Authenticated user & claims
│   ├── state_users.dart         # User collection management
│   ├── state_analytics.dart     # Firebase Analytics wrapper
│   ├── state_notifications.dart # Push notification handling
│   ├── state_collection.dart    # Generic Firestore collection state
│   ├── state_document.dart      # Generic Firestore document state
│   ├── state_api.dart           # HTTP API call state
│   └── ...
│
├── serialized/         # JSON-serializable data models
│   ├── user_data.dart / user_data.g.dart
│   ├── media_data.dart / media_data.g.dart
│   ├── logs_data.dart / logs_data.g.dart
│   ├── chart_*.dart
│   ├── iso_data.dart   # ISO country/language data
│   ├── gsm_data.dart   # GSM provider data
│   └── ...             # +15 domain models
│
├── helper/             # Utility functions and services
│   ├── firestore_helper.dart    # Timestamp serialization
│   ├── firebase_storage_helper.dart
│   ├── provider_helper.dart     # Provider lookup utilities
│   ├── user_roles.dart          # Role-based access control
│   ├── input_validation.dart    # Form validators
│   ├── jwt.dart                 # JWT parsing
│   ├── iso_countries.dart       # Full ISO 3166-1 dataset
│   ├── iso_language.dart        # ISO 639-1 language codes
│   ├── gsm.dart                 # GSM mobile network providers
│   ├── format_data.dart         # Data formatters
│   ├── utils.dart               # General utilities
│   └── ...
│
├── view/               # Full-page view widgets
│   ├── view_auth_page.dart
│   ├── view_featured.dart
│   └── view_hero.dart
│
├── placeholder/        # Loading states & defaults
│   ├── loading_screen.dart
│   └── default_locales.dart
│
└── variables.dart      # Global constants (kIsTest flag)
```

**Layering Principles:**
- **Presentation Layer:** `component/` and `view/` contain stateless/stateful widgets
- **State Layer:** `state/` classes extend `ChangeNotifier` or specialized base classes
- **Domain/Data Layer:** `serialized/` models represent business entities with `fromJson`/`toJson`
- **Infrastructure Layer:** `helper/` provides cross-cutting concerns (validation, formatting, Firebase utilities)

---

## Getting Started & Installation

### Prerequisites

- **Flutter SDK:** Version 3.11.5 or higher
- **Dart SDK:** Version 3.11.5 or higher
- **Firebase Project:** Configure Firebase for your target platforms (iOS, Android, Web)

### Setup Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/FabricElements/fabric_flutter.git
   cd fabric_flutter
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to your platform directories
   - Ensure Firebase is initialized in your app entry point (see `InitApp` component)

4. **Run Code Generation** (for serialization models)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
   Or use the npm script:
   ```bash
   npm run serialize
   ```

5. **Run the Application**
   - **Mobile (iOS/Android):**
     ```bash
     flutter run --no-sound-null-safety --hot
     ```
   - **Web:**
     ```bash
     flutter run --hot web --no-sound-null-safety
     ```

### Building for Release

- **iOS:**
  ```bash
  flutter build ios --release --no-sound-null-safety
  ```

- **Android (App Bundle):**
  ```bash
  flutter build appbundle --release --no-sound-null-safety
  ```

---

## Core Workflows & Logic

### 1. Application Initialization

**Entry Point:** The `InitApp` component bootstraps the entire application.

| Step | Class | Responsibility |
|------|-------|----------------|
| 1 | `InitApp` | Installs core providers (`StateGlobal`, `StateUser`, `StateAnalytics`, `StateNotifications`, `StateUsers`, `StateViewAuth`) |
| 2 | `StateGlobal` | Loads package metadata, monitors network connectivity via `connectivity_plus` |
| 3 | `StateUser` | Listens to `FirebaseAuth.authStateChanges()`, fetches ID token and custom claims |
| 4 | `StateAnalytics` | Configures Firebase Analytics with user properties |
| 5 | `StateNotifications` | Requests permission and sets up FCM token handling (if enabled) |

**Usage:**
```dart
void main() {
  runApp(
    InitApp(
      notifications: true,
      child: MyApp(),
    ),
  );
}
```

### 2. Authentication Flow

| User Action | System Response |
|------------|-----------------|
| User signs in via Google | `StateUser` receives auth state change from Firebase Auth |
| | `StateUser._getToken()` fetches JWT with custom claims |
| | `StateUser._loadUser()` loads user document from Firestore (`users/{uid}`) |
| | `StateUser._updateStatus()` writes online/offline status to Firestore |
| | `StateAnalytics` logs `login` event with user ID |
| User signs out | `StateUser.signOut()` clears local state and calls `FirebaseAuth.signOut()` |
| | `StateUser` broadcasts `UserStatus.signedOut` via `streamStatus` |

**Key Methods:**
- `StateUser.signInWithGoogle()` — OAuth flow for Google Sign-In
- `StateUser.signOut()` — Clears authentication and resets state
- `StateUser.streamStatus` — Broadcasts `UserStatus` changes to UI

### 3. Firestore Data Synchronization

**Generic State Classes:**
- `StateDocument<T>` — Manages a single Firestore document with real-time updates
- `StateCollection<T>` — Manages a Firestore collection with query, filtering, and pagination

**Example Workflow (User Profile Update):**
1. UI calls `stateUser.update({'displayName': 'New Name'})`
2. `StateDocument.update()` performs optimistic local update
3. Debounced write to Firestore after 500ms (configurable)
4. On server write success, snapshot listener confirms new state
5. UI automatically rebuilds via `notifyListeners()`

### 4. Media Upload Flow

| Step | Component | Action |
|------|-----------|--------|
| 1 | `UploadImageMedia` | User selects image via `image_picker` or `file_picker` |
| 2 | Image processing | Resize/compress using `image` package |
| 3 | `FirebaseStorageHelper` | Upload to Firebase Storage with progress tracking |
| 4 | Metadata update | Store download URL in `MediaData` model |
| 5 | Firestore sync | Save `MediaData` to Firestore collection |

### 5. State Lifecycle & Reactivity

**Provider Pattern:**
- All state classes extend `ChangeNotifier`
- UI widgets use `Provider.of<StateUser>(context)` or `context.watch<StateUser>()`
- Components call `notifyListeners()` to trigger UI rebuilds

**Stream-Based Events:**
- `StateGlobal.streamConnection` — Network connectivity changes
- `StateUser.streamStatus` — User authentication state transitions
- `StateUser.streamUser` — Raw Firebase `User` object changes

---

## Codebase Best Practices

### Code Style & Formatting

1. **Linting:** The project uses `flutter_lints` with additional rules:
   - `avoid_print: true` — Use `debugPrint()` or structured logging
   - `prefer_single_quotes: true` — All strings use single quotes

2. **Trailing Commas:** Always include trailing commas for function arguments and parameters to enable auto-formatting:
   ```dart
   MyWidget(
     key: key,
     child: child,  // <-- Trailing comma
   );
   ```

3. **Documentation Standards:**
   - **All public APIs** must follow the [Effective Dart: Documentation](https://dart.dev/guides/language/effective-dart/documentation) guidelines
   - Use triple-slash (`///`) comments with:
     - Capitalized first sentence
     - Markdown formatting for code references (`` `ClassName` ``, `` `methodName()` ``)
     - Descriptive parameter documentation
   - Example:
     ```dart
     /// Loads package metadata from the underlying platform.
     ///
     /// Errors are ignored because test environments and some nonstandard runners
     /// may not expose package information.
     void _initPackageInfo() { ... }
     ```

4. **Null Safety:** The project currently runs with `--no-sound-null-safety` flag during development. Serialized models use null-tolerant deserialization (e.g., `json ?? {}` fallbacks).

### Architectural Guidelines

1. **State Management:**
   - Use `Provider` for dependency injection
   - Check provider availability with `ProviderHelper.isProviderDefined<T>(context)` before access
   - Avoid direct Firebase SDK calls in UI — route through state classes

2. **Data Serialization:**
   - All domain models in `serialized/` must use `json_annotation`
   - Run `build_runner` after modifying model fields
   - Use `FirestoreHelper` utilities for `Timestamp` conversions

3. **Component Design:**
   - Components in `component/` should be self-contained and reusable
   - Accept callbacks (`VoidCallback`, `ValueChanged<T>`) for user interactions
   - Use `const` constructors wherever possible for performance

4. **Testing:**
   - Detect test environments with `kIsTest` flag (from `variables.dart`)
   - Use this to disable Firebase interactions during unit tests

### Contributing Workflow

1. Fork the repository and create a feature branch
2. Add or update tests for your changes (see `test/` directory)
3. Run linters and tests:
   ```bash
   flutter analyze
   flutter test
   ```
4. Ensure code generation is current:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
5. Follow commit conventions and submit a pull request
6. See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines

---

## Debug & Development Tips

### Android Google Sign-In Issues

If Android emulator Google Sign-In fails:
1. Open `android/` folder in Android Studio
2. Sync Gradle and resolve any build errors
3. Verify `applicationId` in `android/app/build.gradle`
4. Update Kotlin version to latest in Gradle files
5. Generate SHA-1 and SHA-256 certificates ([instructions](https://developers.google.com/android/guides/client-auth))
6. Add fingerprints to Firebase Console
7. Re-download `google-services.json`
8. Clean and rebuild project in Android Studio

### Working with Ignored Files

Some configuration files can be ignored locally:

- **Skip tracking:**
  ```bash
  git update-index --skip-worktree default_values.txt
  ```

- **Resume tracking:**
  ```bash
  git update-index --no-skip-worktree default_values.txt
  ```

- **List skipped files:**
  ```bash
  git ls-files -v . | grep ^S
  ```

---

## Additional Resources

- **Issues & Bugs:** [GitHub Issues](https://github.com/FabricElements/fabric_flutter/issues)
- **Contributing Guide:** [CONTRIBUTING.md](CONTRIBUTING.md)
- **License:** [BSD 3-Clause License](LICENSE)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)

---

## Context Map for AI Tools

**Purpose:** This section provides deterministic context for automated code analysis and generation tools.

**Key Entry Points:**
- `lib/component/init_app.dart` — Application bootstrap
- `lib/state/state_user.dart` — Authentication state machine
- `lib/helper/utils.dart` — General utility functions
- `lib/serialized/user_data.dart` — Primary user domain model

**State Management Pattern:** Provider-based `ChangeNotifier` architecture with specialized state classes for different concerns (user, analytics, notifications, documents, collections).

**Serialization Strategy:** `json_serializable` with null-tolerant factories (`json ?? {}`), `FirestoreHelper` for `Timestamp` handling.

**Firebase Integration Points:** All Firebase interactions route through `state/` classes or `helper/` utilities, never directly in UI components.

**Testing Context:** Use `kIsTest` flag from `variables.dart` to conditionally disable Firebase in test environments.