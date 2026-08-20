## [Unreleased]

### Performance
* Fixed `InitAppChild` (`lib/component/init_app.dart`) registering a **new, never-cancelled** `StateUser.streamStatus` subscription on every `build()`. Because the widget was a `StatelessWidget` and the `StreamSubscription` was discarded, every rebuild stacked another listener on top of the previous ones, so analytics `setUserId` and the whole `StateNotifications` init/`getUserToken` sequence re-ran once per accumulated subscription for every `UserStatus` event. `InitAppChild` is now a `StatefulWidget` that subscribes once in `initState`, stores the subscription, and cancels it in `dispose`. The one-shot `WidgetsBinding.addPostFrameCallback` that called `StateGlobal.init()`/`StateUser.init()` moved to `initState` for the same reason.
* Fixed `InitAppChild` forcing a **complete teardown and rebuild of the entire application subtree on every rebuild**. The wrapper's key was `ValueKey('init-app-child-${status?.signedIn}-$now')` where `now` was `DateTime.now().millisecondsSinceEpoch`, so the key was different every single time and Flutter unmounted and recreated every descendant widget — discarding all their `State`, scroll positions, controllers, and re-running every `initState`. The key is now `ValueKey('init-app-child-${status?.signedIn}')`, which preserves the intended behavior (rebuild the subtree when the sign-in state flips) without the per-frame churn. The wrapper is also a `KeyedSubtree` instead of a `Container`, removing a redundant render object.
* Fixed `StateShared.data`'s de-duplication guard never actually firing for Firestore and HTTP payloads (`lib/state/state_shared.dart`). The guard compared with `==`, which is *referential* for `Map` and `List`, and Firestore allocates a fresh map/list for every snapshot — so every snapshot, identical or not, notified every listening widget in every consuming app. The setter now compares structurally with `DeepCollectionEquality` behind an `identical()` fast path, so a snapshot that renders identically no longer triggers a rebuild.
* Moved image decoding, resizing, and encoding off the UI isolate in `MediaHelper` (`lib/helper/media_helper.dart`). `resize()` and the camera capture path called `img.decodeImage`, `img.copyResize`, `img.encodeJpg`, and `img.encodePng` synchronously on the main isolate, freezing the UI for the duration (hundreds of milliseconds for a multi-megapixel photo). The work now runs through `compute()`, with the same web/failure fallback pattern already used by `StateAPI` for streamed JSON parsing.
* Fixed `PaginationContainer` (`lib/component/pagination_container.dart`) leaking its stream subscription. `initState` discarded the `StreamSubscription` returned by `listen()`, and `dispose` called `stream.drain()` — which attaches a *second* listener rather than releasing the first one — so the original subscription kept processing events after the widget was unmounted. The subscription is now stored and cancelled in `dispose`.
* Hoisted the per-build filtering and sorting out of `FilterMenu.build` (`lib/component/filter_menu.dart`). Two `O(n log n)` sorts plus a `FilterHelper.filter` pass and an option-mapping pass ran on every build — which for a filter menu means every keystroke, every chip toggle, and every ancestor rebuild. They now run in `_recomputeOptions()`, invoked only from `initState`/`didUpdateWidget`/`didChangeDependencies` when the filter collection actually changes; `build` only copies the cached active list before mutating it.
* Replaced `Query.parameters.toString().hashCode` comparisons in `StateCollection` (`lib/state/state_collection.dart`) with a structural `DeepCollectionEquality` check. Stringifying and hashing was both more expensive on large `whereIn`/`arrayContainsAny` payloads and collision-prone — a hash collision would leave a stale Firestore listener attached when the query had genuinely changed.
* Added equality guards to setters that previously notified unconditionally: `StateViewAuth.phone`, `phoneVerificationCode`, `verificationId`, and `section` (`lib/state/state_view_auth.dart`), and `StateShared.selected` (`lib/state/state_shared.dart`). These are commonly re-assigned per keystroke or from a parent rebuild with an unchanged value, and each redundant `notifyListeners()` fans out to every listening widget in every consuming app.
* Narrowed over-broad `MediaQuery.of(context)` dependencies to the specific aspect being read: `MediaQuery.platformBrightnessOf` in `InitAppChild` and `MediaQuery.devicePixelRatioOf` in `SmartImage` (`lib/component/smart_image.dart`). `MediaQuery.of` subscribes to the entire `MediaQueryData`, so both widgets previously rebuilt on every resize, rotation, text-scale change, and safe-area change.
* Narrowed the bare `import 'dart:io'` directives in `lib/variables.dart`, `lib/component/google_maps_preview.dart`, `lib/state/state_user.dart`, `lib/helper/media_helper.dart`, and `lib/helper/firebase_storage_helper.dart` to `show Platform` / `show File`, so web builds and tree-shaking only pull in the symbol that is actually used.

### Fixed
* **Fixed a buggy URL validation pattern.** `RegexHelper.url` is **unanchored**, so it reported a match for any string that merely *contained* something URL-shaped — `'garbage https://example.com'`, `'xhttps://example.com'`, and `'https://example.com trailing junk'` all passed. That made it unsuitable as a form validator, which is how `InputValidation.isUrlValid` (and therefore `validateUrl`) was using it. Added the anchored `RegexHelper.urlStrict` (`^https?://...$`) and switched `InputValidation.isUrlValid`/`validateUrl` over to it. **This is an intentional behavior change:** those three inputs now correctly fail validation. Every genuinely well-formed URL that passed before still passes — verified against `https://example.com`, `http://example.com/path`, `https://example.com/a?b=c#d`, and `https://sub.example.co.uk/x`. `RegexHelper.url` itself is unchanged and still exported for backwards compatibility, but is now documented as a contains-a-URL pattern that should not be used for validation.
* Fixed `MediaHelper.getFile` (`lib/helper/media_helper.dart`) throwing `UnsupportedError` on web when a video was selected. The video-dimension probe called `File.fromRawPath` — a `dart:io` API with no web implementation — without a `kIsWeb` guard. The probe is now skipped on web, where raw-byte dimension extraction is not possible anyway.
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

### Changed
* Reworked `InputValidation` phone validation (`lib/helper/input_validation.dart`) to parse with `PhoneNumberUtil` (from `dlibphonenumber`) exactly like `PhoneInput.formatInput()`, instead of a length-only regex. `isPhoneValid` now returns `true` only when `PhoneNumberUtil.isValidNumber` accepts the parsed number and gained an optional `defaultCountry` (defaults to `US`) used as the region for numbers without an international `+` prefix. The previous digit-only regex validator (`validatePhone`) was renamed to `validatePhoneNoPlusSign` to make room for the new parser-backed `validatePhone`. `PhoneInput` now constructs its `InputValidation` with the selected country as `defaultCountry` so the national-number field validates against the chosen country.
* Refactored `UserAddUpdate` (`lib/component/user_add_update.dart`) to build its phone field with the dedicated `PhoneInput` component (`lib/component/phone_input.dart`) instead of a bare `InputData(type: InputDataType.phone)`. The form now gets `PhoneInput`'s country-code picker, per-country parsing/validation via `PhoneNumberUtil`, and normalized E.164-style output written back to `UserData.phone`, keeping phone entry consistent with the rest of the package. `PhoneInput` also gained a `required` flag (defaults to `false`) that is forwarded to its underlying national-number `InputData`, so the field advertises the same asterisk/pending "Required" affordances and `Semantics.hint` as other required inputs; `UserAddUpdate` passes `required: true`.

### Added
* Added `lib/fabric_flutter.dart`, a public entrypoint that re-exports the package's components, helpers, state containers, serialized models, and views. Consumers can now `import 'package:fabric_flutter/fabric_flutter.dart';` instead of deep path imports. Existing deep imports are unaffected — this is purely additive. (The top-level `db` symbol, which is declared in both `state_user.dart` and `state_users.dart`, is hidden from the `state_users.dart` export to keep the barrel unambiguous; it remains reachable via a deep import.)
* Consolidated **every** regular expression in the package into `RegexHelper` (`lib/helper/regex_helper.dart`), which is now the single source of truth. All patterns are `static final RegExp` compiled once at class level — never inside a function, `build()`, or item builder — and each is documented with what it matches, what it does *not* match, and a matching/non-matching example. All existing members (`email`, `phone`, `phoneNoPlusSign`, `url`, `password`, `username`) are unchanged and backwards-compatible. Newly added: `urlStrict`, `urlInText`, `uuid`, `mimePrimaryType`, `htmlTag`, `whitespace`, `multipleSpaces`, `extraNewlines`, `formattingOnly`, `nonDigits`, `plusSign`, `phoneDeniedInput`, `phoneAllowedInput`, `decimalAllowedInput`, `intAllowedInput`, `nonAlphanumeric`, `nonAlphanumericRun`, `slug`, `nonSlug`, `leadingSlash`, `trailingPunctuation`, `searchSanitize`, `nameSanitize`, `listSeparators`, `placeholder`, `localizationKeyPath`, `invalidLocaleChars`, and `camelCaseBoundary`. Names shared with the downstream `furcata/app` consolidation (`whitespace`, `nonAlphanumeric`, `trailingPunctuation`, `slug`, `urlStrict`, `urlInText`, `mimePrimaryType`) deliberately match so that consumer can drop its local copies. Duplicate private literals were removed from `input_data.dart`, `phone_input.dart`, `section_title.dart`, `logs_list.dart`, `profile_edit.dart`, `filter_menu.dart`, `app_localizations_delegate.dart`, and `gsm.dart`; three equivalent `{.*?}` placeholder patterns and two equivalent phone-input filter pairs collapsed into one canonical definition each. No validation semantics changed.
* Added an optional `limit` parameter to `UserRolesFirebase.getUsers` (`lib/helper/user_roles_firebase.dart`). The method previously read *every* document in the `user` collection with no bound. `limit` defaults to `null`, which preserves the existing unbounded behavior for current callers, and the doc comment now warns about the cost and points at `StateCollection` for pagination.
* Added `InputValidation.isUsernameValid` and `InputValidation.validateUsername` (`lib/helper/input_validation.dart`), reusing the shared `RegexHelper.username` pattern (`^[a-z0-9]{3,30}$`: lowercase ASCII letters and digits only, 3-30 characters). `validateUsername` is `FormFieldValidator<String>`-compatible and returns the new localized `validation--username` (en/es) message on failure. `UserAddUpdate` (`lib/component/user_add_update.dart`) now validates its username field with `validateUsername` and requires a well-formed handle (not merely a non-empty value) before submitting.
* Added `InputValidation.validatePhone`, a `FormFieldValidator<String>`-compatible validator that returns a localized error message chosen with a `switch` over `dlibphonenumber`'s `ErrorType` (invalid country calling code, not a number, too short, too long). Because national-number input (as entered in `PhoneInput`) usually parses successfully rather than throwing, when a parsed number is not valid the validator additionally inspects `PhoneNumberUtil.isPossibleNumberWithReason` and switches over its `ValidationResult` to still report *too short* / *too long* / *invalid country code* (treating `isPossibleLocalOnly` as too short), only falling back to the generic `validation--phone` message for otherwise-possible-but-invalid or empty/`null` input. Added the localized keys `validation--phone-invalid-country-code`, `validation--phone-not-a-number`, `validation--phone-too-short`, and `validation--phone-too-long` (en/es) to `default_locales.dart`.
* Added a `required` flag to `InputData` (`lib/component/input_data.dart`) so mandatory fields advertise themselves without callers hand-rolling per-field messaging. When `required` is `true` the field appends a colored asterisk (`theme.colorScheme.error`) to its label, shows a subtle localized "Required" helper (`label--required`) while the value is still empty (pending), and — for text-based variants that already run `AutovalidateMode.onUserInteraction` — escalates to a red `validation--required` error once an empty field is interacted with. The required/pending state is also woven into the `Semantics.hint` ("Required field, currently empty and pending input." vs "Required field.") so screen readers and autonomous agents know the field is mandatory and whether it is unfilled. An externally supplied `error` still takes precedence over the pending helper. `user_add_update.dart` now marks its first-name, last-name, and password inputs as `required`. Added `label--required` and `validation--required` (en/es) to `default_locales.dart`.
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
