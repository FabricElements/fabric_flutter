---
applyTo: "lib/**/*.dart"
---

# Dart Documentation Instructions

These rules apply to all Dart source files under `lib/` and follow [Effective Dart: Documentation](https://dart.dev/effective-dart/documentation).

- Document **every** API element — public and private classes, constructors, fields, methods, enums, enum values, and top-level declarations — with triple-slash `///` doc comments. Never use `/* */` blocks or plain `//` for API documentation.
- Begin with a single-sentence summary that is capitalized, ends with a period, and starts with a third-person present-tense verb (e.g., "Builds…", "Stores…", "Provides…", "Determines…").
- Separate the summary from additional detail with a blank `///` line; explain *why* and edge-case behavior, not just *what*.
- Reference in-scope identifiers with **square brackets** — `[BuildContext]`, `[StateShared]`, `[stream]` — and use backticks for literals and code such as `` `null` `` or `` `Authorization` ``.
- Do **not** use `@param`, `@returns`, `@throws`, or other Javadoc-style tags; describe parameters, return values, and errors in prose.
- Avoid redundant openers like "This class…" or "A method that…".
- Use Markdown inside doc comments and keep lines reasonably short.
- Canonical examples to imitate: `lib/state/state_shared.dart`, `lib/helper/route_helper.dart`, `lib/serialized/password_data.dart`.
- Code style in these files: single-quoted strings, mandatory trailing commas on multi-line argument lists, `const` constructors where possible, `debugPrint()` instead of `print()`.
