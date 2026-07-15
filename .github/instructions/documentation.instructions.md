---
applyTo: "lib/**/*.dart"
---

# Dart Documentation Instructions

These rules govern all Dart source under `lib/` and implement [Effective Dart: Documentation](https://dart.dev/effective-dart/documentation). They are enforced for **both** human- and AI-generated code so the two stay indistinguishable.

## Core rules

- Document **every** API element — public **and** private: classes, mixins, enums, enum values, constructors, fields, getters/setters, methods, top-level functions, and top-level variables. Use triple-slash `///` doc comments **only**. Never use `/* */` blocks or plain `//` for API documentation.
- Begin with a **single-sentence summary**: capitalized, ending with a period, starting with a **third-person present-tense verb** ("Builds…", "Stores…", "Provides…", "Determines…", "Returns…", "Throws…").
- Separate the summary from further detail with a **blank `///` line**, then explain the *why*, edge cases, and non-obvious behavior — not just the *what*.
- Reference in-scope identifiers with **square brackets**: `[BuildContext]`, `[StateShared]`, `[stream]`, `[semanticHint]`. Use backticks for literals/code: `` `null` ``, `` `Authorization` ``, `` `2xx` ``.
- **Do not** use Javadoc-style `@param`, `@returns`, `@throws`, or any `@`-tag. Weave parameter, return, and error behavior into prose.
- Avoid redundant openers like "This class…", "A method that…", or "Getter for…".
- Doc comments use Markdown; keep lines reasonably short. External references (spec/MDN links) may follow the prose on their own line.

## API documentation of contracts (HTTP / errors / enums)

- For helpers that model an external contract (e.g. `AuthScheme`, `HTTPMethod` in `http_request.dart`), document each enum value with what protocol token or verb it maps to, and link the authoritative spec (MDN, etc.).
- Document error behavior in prose on the throwing member, e.g. describe the fallback order a method uses to build an error message and what it throws (the codebase throws plain `String` messages — say so).

## Changelog documentation

- User-facing or behavioral changes must be recorded in `CHANGELOG.md` (newest first, matching the existing category style: `### Added` / `### Changed` / `### Fixed` / `### Dependencies`, with issue references like `(issue #123)`). Pure private-refactor or doc-only changes to code comments do not require a changelog entry unless they alter behavior.

## Examples

**DO**

```dart
/// Builds common HTTP authentication headers and response helpers.
///
/// Centralizes how `Authorization` headers are formatted and how error
/// responses are interpreted so low-level networking stays consistent.
class HTTPRequest {
  /// Creates an [HTTPRequest] helper.
  ///
  /// When either [credentials] or [authScheme] is provided, both must be set
  /// so a valid `Authorization` header can be built.
  const HTTPRequest({this.credentials, this.authScheme});

  /// Declares how [credentials] should be labeled in the header.
  ///
  /// Use [AuthScheme.Bearer] for most token-based APIs unless the backend
  /// explicitly expects another scheme.
  final AuthScheme? authScheme;

  /// Throws a best-effort error message extracted from [response].
  ///
  /// Successful `2xx` responses return normally. For failures the helper
  /// prefers a JSON `message`, then a JSON `errors` list, then the HTTP
  /// reason phrase, and finally falls back to an `error--statusCode` key.
  static void error(Response response) { /* ... */ }
}
```

**DO NOT**

```dart
// A class for http requests            <-- plain // for API docs
/**                                     <-- block comment
 * @param response the http response    <-- Javadoc @-tags
 * @returns nothing
 */
/// getter for the auth scheme          <-- lowercase, redundant opener, no verb
AuthScheme? get authScheme => _authScheme;
```

## Canonical files to imitate

`lib/state/state_shared.dart`, `lib/helper/route_helper.dart`, `lib/helper/http_request.dart`, `lib/serialized/password_data.dart`, `lib/component/smart_button.dart`.

## Code style inside documented files

Single-quoted strings, mandatory trailing commas on multi-line argument lists, `const` constructors where possible, `debugPrint()` (never `print()`), `final` fields. See `.github/copilot-instructions.md` §4.
