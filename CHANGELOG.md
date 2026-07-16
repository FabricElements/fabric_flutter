## [Unreleased]

### Fixed
* Fixed `VoiceDictationButton` triggering iOS `error_unknown (300)` (`kAFAssistantErrorDomain`) when a new press started a fresh recognition session before the previous session's `stop()` had finished tearing down on the platform side. The widget now guards against re-entrant starts and awaits the pending `stop()` before requesting a new `listen()` session.
* Fixed `VoiceDictationButton` surfacing `error_unknown (300)` (and similar iOS teardown noise) as a user-facing error even when the button was no longer pressed. `speech_to_text` only honors the `onError`/`onStatus` callbacks passed to the *first* `initialize()` call for the lifetime of its singleton — every later call is a no-op — so the same error listener kept receiving delayed native teardown events from already-stopped sessions. The listener now discards any error that doesn't correspond to a session currently being requested or actively listened to.
* Fixed `VoiceDictationButton` still surfacing `error_unknown (300)` even after the above fix, because the native session can also emit this code while the button is genuinely still being held (e.g. the platform's own end-of-utterance/pause detection ends the recognition task "unsuccessfully" before the user releases). `kAFAssistantErrorDomain` code 300 (like Android's equivalent catch-all) is simply the platform's generic "task finished without a match" signal, not an actionable failure — the underlying package itself only maps a handful of codes (permission/config/network/assets) to anything specific. `_handleError` now classifies error messages: benign end-of-session codes (`error_no_match`, `error_speech_timeout`, `error_busy`, `error_client`, `error_retry`, `error_request_cancelled`, `error_speech_recognizer_already_active`, `error_speech_recognizer_connection_invalidated`/`_interrupted`, and any unmapped `error_unknown (*)`) are now fully ignored; only genuinely actionable errors (permission denied, disabled recognizer, missing assets, network/server failures, unsupported locale) are still forwarded via `onError` and stop the session.
* Fixed `VoiceDictationButton` appearing to stop listening the instant the button was pressed. The previous benign-error fix still called `stop()` for benign codes, and because the persistent error listener has no way to tell which session an event actually belongs to, stale `error_unknown`/`error_no_match`-style noise from the *previous* session frequently arrived right as a new session was starting, immediately ending it. Benign errors are now fully discarded — neither reported nor treated as a reason to stop — so a fresh press-and-hold session is no longer interrupted by leftover teardown noise from the last one.
* Fixed `VoiceDictationButton` going silent (mic still showed "listening" but no further transcripts/callbacks ever arrived) after the previous fix, because on some devices `error_unknown (300)` genuinely reflects the *current* recognition task ending (e.g. the platform's own end-of-utterance/pause timeout) rather than stale noise, and fully ignoring it left `_listening` stuck `true` with a dead recognizer underneath. `_handleError` now transparently requests a fresh `listen()` task when a benign error arrives while the button is still held, instead of doing nothing, so dictation keeps going without the caller ever seeing a gap. Because each new task starts fresh recognition, already-recognized words are now committed into an accumulator before restarting so `onPartialTranscript`/`onFinalTranscript` keep reporting the full combined transcript across the restart instead of only the newest segment.
* Fixed a possible silent infinite-restart loop introduced by the auto-restart fix above: if the recognizer keeps ending benignly on every single restart attempt without ever producing one real result (e.g. a broken audio route/permission state that fails the same way every time), the button would appear stuck "listening" forever while never reporting any transcript or telling the caller why. After 3 consecutive benign restarts without a result, the error is now finally surfaced via `onError` and the session stops instead of retrying silently forever; any real result resets the counter.
* Fixed `VoiceDictationButton` letting an exception thrown by a caller-supplied callback (`onPartialTranscript`, `onFinalTranscript`, `onListeningChanged`, `onAvailabilityChanged`) propagate and crash the recognizer lifecycle. Every callback invocation is now wrapped and any failure is routed to `onError` instead (a throwing `onError` itself is caught and only logged via `debugPrint` under `kDebugMode`, since there is nowhere further to report it).
* Applied the same callback-safety pattern across the rest of the package wherever an external callback is invoked from code we control (async/listener contexts, not synchronous Flutter gesture dispatch which the framework already protects):
  * `StateShared` (`lib/state/state_shared.dart`, the base for `StateDocument`/`StateCollection`/`StateAPI`/`StateUsers`) now guards its `callback` and `onError` invocations — a throwing `callback` or `onError` no longer prevents `notifyListeners()`/`stream`/`streamError` from still publishing the update, and is only logged via `debugPrint`/`LogColor` under `kDebugMode`.
  * `PaginationContainer` and `StepperExtended` now guard their `onScrollOffsetChanged` scroll-listener callback so a throwing callback can no longer skip the pagination-detection logic that runs after it in the same listener. Both widgets now expose a new optional `onError` (`ValueChanged<String>?`) so consumers have a dedicated place to receive these (and other internal) errors instead of only a debug log; `PaginationContainer.onError` also now receives `paginate()` and stream failures that previously were only reflected in the inline error footer.
* Fixed `StepperExtended` never actually reporting scroll offset changes: `build()` created a second, unrelated `ScrollController` for the visible `SingleChildScrollView`/`Scrollbar` instead of reusing the `_controller` field that `onScrollOffsetChanged` was registered against, so the listener was permanently dead code. Both now share the same controller.

### Added
* Added `VoiceDictationButton` (`lib/component/voice_dictation_button.dart`), a self-contained, press-and-hold microphone widget built on `speech_to_text` that streams partial/final transcripts through constructor callbacks only — no `TextEditingController`, no app-level state writes. Uses a `Listener` (pointer down/up/cancel) instead of `GestureDetector.onLongPress` for immediate response, and guards against late/async recognition results after release. Tooltip labels (`label--hold-to-dictate`, `label--listening`) are resolved through `AppLocalizations`/`default_locales.dart` (en/es) instead of being hardcoded.
* Added a haptic tap to `VoiceDictationButton` — `HapticFeedback.mediumImpact` when listening genuinely starts, `HapticFeedback.lightImpact` when it genuinely stops — so the user gets tactile confirmation of press-and-hold without needing to watch the mic icon. Controlled by the new `enableHapticFeedback` constructor parameter (defaults to `true`); never re-fires for the transparent internal restarts described above, since dictation never actually stopped from the user's perspective. The button's own built-in `IconButton.enableFeedback` is now disabled to avoid a redundant, generic platform tap vibration alongside the explicit one.

### Documentation
* Documented in the README that `VoiceDictationButton` must be tested on a physical iOS device rather than the Simulator: the Simulator's microphone input is unreliable for `SFSpeechRecognizer` and can silently produce zero results (no error, no transcript) even though listening otherwise starts/stops normally — a Simulator/OS limitation outside the widget's control.

### Dependencies
* Added `speech_to_text` ^7.4.0.

### Material 3 UI Adjustments
* **[Deprecation]** Replaced the Material-2-era `RawMaterialButton` with `InkWell`/`GestureDetector` in `lib/component/alert_data.dart`, `lib/component/input_data.dart`, `lib/component/profile_edit.dart`, `lib/component/card_button.dart`, and `lib/view/view_featured.dart`, so ripple, focus/hover state layers, and disabled styling track `ThemeData`/`ColorScheme` (issue #177).

### Cleanup
* Removed a commented-out, deprecated `MediaQuery.textScaleFactor` reference in `lib/component/smart_button.dart`.
* Reworded `lib/component/stepper_extended.dart` doc comments to drop the no-op `ThemeData.useMaterial3` conditional wording.
* Removed a stale commented-out `Theme.of(context).primaryColor.value` sample line in `lib/helper/utils.dart`.

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
