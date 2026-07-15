## [Unreleased]

### CI
* Bumped CI Flutter SDK version from 3.44.4 to 3.44.6.
* Bumped CI Flutter SDK version from 3.44.1 to 3.44.4.

## [2.2.5] - 2026-07-15

### Web/WASM Modernization
* **[Deprecation]** Replaced `universal_html` (`dart:html`) with `package:web` and `dart:ui_web` in `lib/component/iframe_minimal_web.dart`, removing the last `dart:html` dependency and unblocking `flutter build web --wasm` (issue #175).
* Switched the `iframe_minimal.dart` conditional export from `dart.library.html` to `dart.library.js_interop`, which is available on both the JavaScript and WebAssembly web compilation targets.

### Dependencies
* **[Fix]** Downgraded `build_runner` constraint from ^2.15.2 to ^2.15.1 to resolve version solving failure with Flutter SDK 3.44.1 (`meta` pin at 1.18.0 is incompatible with `build_runner >=2.15.2` which requires `meta ^1.18.3`).
* **[Fix]** Downgraded `intl` constraint from ^0.20.3 to ^0.20.2 to satisfy the `intl 0.20.2` pin from `flutter_localizations` in Flutter SDK 3.44.1, resolving version solving failure.
* Removed `universal_html: ^2.3.0`.
* Added `web: ^1.1.1`.

## [2.2.4] - 2026-07-15

### Dependencies
* **[Dependency Modernization]** Bumped 15 dependencies to latest versions (issue #176)
  * **`package_info_plus`**: ^9.0.1 → ^10.2.1 (major version bump; no breaking API changes)
  * Firebase suite updates (unblocks transitive `firebase_core_platform_interface` 7→8):
    * `firebase_core`: ^4.11.0 → ^4.12.1
    * `cloud_firestore`: ^6.6.0 → ^6.7.1
    * `cloud_functions`: ^6.3.3 → ^6.3.5
    * `firebase_auth`: ^6.5.4 → ^6.5.6
    * `firebase_analytics`: ^12.4.3 → ^12.4.5
    * `firebase_messaging`: ^16.4.1 → ^16.4.3
    * `firebase_storage`: ^13.4.3 → ^13.4.5
    * `firebase_database`: ^12.4.4 → ^12.4.6
  * Minor package updates:
    * `connectivity_plus`: ^7.2.0 → ^7.3.0
    * `video_player`: ^2.11.1 → ^2.13.0
    * `flutter_markdown_plus`: ^1.0.11 → ^1.0.12
    * `intl`: ^0.20.2 → ^0.20.3
  * Dev dependency updates:
    * `build_runner`: ^2.15.0 → ^2.15.2
* Pre-1.0 dependency health verified:
  * `json_explorer: ^0.1.2` — community fork of abandoned json_data_explorer; actively maintained
  * `devicelocale: ^0.9.0` — active maintenance; compatible with current SDK
  * `image_network: ^2.6.0` — maintained; complements SmartImage for network image loading
  * `omni_datetime_picker: ^2.3.2` — current and compatible with Flutter 3.44.x

### Documentation & Code Quality
* **[MAJOR]** Comprehensive codebase compliance sweep (June 2026)
  * All 41 component files now fully documented to Effective Dart standards
  * All 22 helper files reviewed and documented
  * All 15 serialized models updated with null-tolerant `fromJson` factories
  * All 10 state files reviewed for code style compliance
  * All 3 view files documented
  * Overall compliance raised from ~65% to ~95%
* Applied Effective Dart documentation standards across entire codebase:
  * Triple-slash `///` comments for all public and private API elements
  * Capitalized first sentences with proper periods
  * Third-person present-tense verb starts
  * Markdown formatting with square brackets for type references
  * Removed Javadoc-style tags in favor of prose documentation
* Enforced code style standards:
  * Single quotes for strings (`prefer_single_quotes: true`)
  * Replaced `print()` with `debugPrint()` throughout
  * Added trailing commas on multi-line function calls
  * Applied `const` constructors where possible
* Serialization improvements:
  * All `fromJson` factories now accept nullable `Map<String, dynamic>?` parameters
  * Added null coalescing (`json ?? {}`) for null-tolerant deserialization
  * 11 classes in `place_data.dart` updated for null safety
  * 2 classes in `user_data.dart` fully documented

### Infrastructure
* Added GitHub Actions CI/CD workflows for automated testing
  * `flutter analyze` runs on all PRs and pushes
  * `flutter test` runs full test suite
  * Prevents regressions in code quality standards
* Added pre-commit hooks to enforce standards locally
  * Automatic code formatting with `dart format`
  * Lint checking with `flutter analyze`
  * Documentation validation
* Updated developer documentation with Flutter-specific guidelines

### Changed
* Updated `CONTRIBUTING.md` with modern Flutter development workflow
* Added compliance validation guide (`PHASE2_VALIDATION.md`)
* Created comprehensive audit reports documenting all changes

### Fixed
* Fixed 5 critical helper files: `enum_data.dart`, `jwt.dart`, `firestore_helper.dart`, `utils.dart`, `log_color.dart`
* Fixed documentation in `AlertType` enum
* Fixed view files: `view_auth_page.dart`, `view_featured.dart`

## [2.2.2] - Previous Release

See git history for changes prior to compliance sweep.
