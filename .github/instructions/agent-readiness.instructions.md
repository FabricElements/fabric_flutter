---
applyTo: "lib/**"
---

# Agent-Readiness Instructions

`fabric_flutter` ships an agent interface: every interactive component can be driven by an
autonomous agent through `AgentBridge`, and the same identity is used by screen readers, widget
tests, and the MCP facade. These rules keep that surface complete and consistent. The reference
documentation already exists and must not be duplicated here:

- [`doc/agent.md`](../../doc/agent.md) — the agent bridge, `AgentElement`, built-in commands, the
  reveal API, `semanticActions`/`announce()`, the MCP facade, and how to add a command.
- [`doc/agent-bridge-protocol.md`](../../doc/agent-bridge-protocol.md) — the wire protocol.
- [`.github/skills/fabric-agent/SKILL.md`](../skills/fabric-agent/SKILL.md) — the condensed
  checklist for making a widget agent-ready or adding a command.

Apply these rules to **any new or changed feature** — agent, MCP, API, scrolling, or otherwise.
They are enforced by the guard tests under `test/guards/`; a new violation fails the suite.

## 1. Every interactive component is agent-ready

An interactive widget is one that accepts `onPressed`, `onChanged`, or `onTap`, or otherwise
responds to user input.

- **Accept an `automationKey` parameter.** Every interactive public widget in `lib/component/`
  exposes `final String? automationKey` in its constructor. Wrapper widgets forward it to the
  widget they wrap (see `UsersDropdown` → `InputData`).
- **Wrap the widget in `AgentElement`** (`lib/helper/agent/agent_element_binding.dart`) when the
  widget does not already do so itself. Keep the pairing **one identity**: `automationKey` is
  simultaneously the agent registry id, the `Semantics.identifier`, the
  `find.bySemanticsIdentifier` finder, and the web `flt-semantics-identifier` DOM attribute.
  Never add a second, separate `Semantics` identifier for the agent.
- **Follow the naming convention** `[RouteName]_[ContextBlock]_[ComponentType]_[ActionOrId]`,
  lowercase snake case (`settings_profile_input_email`). `InputData` derives a key from the route
  and label when none is given; do not invent an alternative scheme.
- **Choose the correct `AgentElementType`.** `button` for actions, `text_input` for free-form
  values, `dropdown`/`radio`/`checkbox` for closed choices, `date_picker` for dates, `text` for
  read-only content, `image` for media, `navigation` for scaffolds and menu entries. `other` is the
  fallback, never the default you reach for. Every type value must be documented in
  `doc/agent.md` §`AgentElementType`.
- **Supply the getters and setters the type implies.** `text_input` needs `valueGetter` + `setter`;
  `button` needs `activator` (or a reachable `ActivateIntent`). Add `enabledGetter`,
  `visibleGetter`, `errorGetter`, and `validatorFn` wherever they carry real information — an agent
  reads them to decide whether an action is possible and why it failed.
- **`optionsGetter` for every choice input.** A `dropdown`, enum, or `radio` element must expose
  its choices so an agent can pick a valid value rather than guess. `InputData` populates this from
  `options`/`enums` with localized labels.
- **`semanticActions` only for actions that already exist and are visible.** Each entry is a
  localized label mapped to a `VoidCallback` for a secondary action on the element (a "Clear" inside
  a text field, a row-level "Delete"). Do not invent an action the UI does not offer, and never
  expose an unlocalized label.
- **Call `announce()`** (`lib/helper/announce.dart`) when state changes in a way that is not visible
  in the element tree — a save that succeeded, a background refresh that failed. It is a no-op where
  announcements are unsupported, so calling it is always safe.
- **Add the semantics test.** Every interactive component with these hooks gets a
  `test/component/<name>_semantics_test.dart` asserting label, identifier, and hint.

## 2. Lazy and nested lists are revealable

An element an agent cannot reach is an element it cannot drive. Any component that renders items
inside a lazy or nested list (`ListView.builder`, `ExpansionTable`, a stepper, paginated content)
must expose the reveal path so a hidden element can be scrolled into view and built: use
`ScrollReveal.reveal` (`lib/helper/scroll_reveal.dart`) and expose a `RevealController`, wiring it
through `AgentElement.revealFn`. See `doc/agent.md` §4.

## 3. New built-in commands are documented, not just registered

Registering a command in `lib/helper/agent/agent_builtin_commands.dart` is only half the change.

- Document it in `doc/agent.md` §3 with its exact parameters and result shape. The guard test
  `test/guards/agent_command_docs_test.dart` fails when a registered id is undocumented.
- Note its MCP name: MCP tool names must match `^[a-zA-Z0-9_-]{1,64}$`, so **dots become double
  underscores** (`element.reveal` → `element__reveal`). The reverse mapping is applied on
  `tools/call`. See `doc/agent.md` §8.3.
- Declare every parameter as an `AgentParam` with an explicit `AgentParamType`, read them through
  `AgentCommandContext`, and throw `AgentException.*` rather than returning an error shape.
- Return a JSON-serializable `Map<String, dynamic>` with stable keys, and add a test under
  `test/helper/agent/`.

## 4. Platform boundaries

The package targets web, iOS, and Android from one source tree.

- **No `dart:io` or `dart:html`/`package:web` leak into shared code.** A file that needs a
  platform-only capability isolates it behind a conditional import or export
  (`export 'x_native.dart' if (dart.library.js_interop) 'x_web.dart';`) — see
  `lib/helper/agent/agent_bridge_server.dart`, `lib/component/iframe_minimal.dart`,
  `lib/component/drop_region.dart`. Never import a platform library into a file that is reachable
  from a different platform.
- `package:web` may only appear inside a `*_web.dart` file that is selected by a conditional
  import/export; `dart:io` only inside a `*_native.dart` file (or a reviewed exception listed in
  `test/guards/platform_imports_test.dart`).
- Live platform/DOM work must be skipped under `kIsTest` so `flutter test` never opens a real
  socket, DOM, or Firebase connection.

## 5. Interaction and API rules

- **No state-management or callback-signature changes.** Agent-readiness is additive: add
  `automationKey`, `semanticsLabel`, `semanticHint`, and `AgentElement` wiring. Do not change how a
  widget manages state, and do not change the shape of an existing callback
  (`VoidCallback`, `ValueChanged<T>`) to carry agent data.
- **This is a published package consumed by pinned commit SHA.** A new `automationKey` parameter is
  nullable and defaulted, so it is additive and safe; removing or renaming one is a breaking change
  for both consumers and agents.
- **Spacing uses `DensitySpacing`** for ordinary content spacing, and structural geometry (icon
  sizes, tap targets, canvas bounds) stays fixed — the density source-scan guard covers this.
- **No new dependencies.** Reuse `AgentElement`, `announce()`, `ScrollReveal`, and the existing
  helpers.

## 6. CHANGELOG

Add an `[Unreleased]` entry to `CHANGELOG.md` for any new agent-facing capability (a new
`automationKey`, element type, command, or MCP mapping). Keep the CHANGELOG and `doc/agent.md`
consistent — if a convention changes, update both, and never document a guarantee the code does not
yet provide.

## Guard tests

| Guard | Enforces |
| --- | --- |
| `test/guards/automation_key_coverage_test.dart` | Every interactive public widget in `lib/component/` accepts `automationKey` (§1). |
| `test/guards/agent_command_docs_test.dart` | Every registered built-in command id is documented in `doc/agent.md` (§3). |
| `test/guards/agent_element_type_docs_test.dart` | Every `AgentElementType` value is documented in `doc/agent.md` (§1). |
| `test/guards/platform_imports_test.dart` | No unguarded `dart:io` / `dart:html` / `package:web` import under `lib/` (§4). |
| `test/guards/agent_readiness_docs_test.dart` | This file exists, is linked from `.github/copilot-instructions.md`, and its guards exist. |

Each guard carries an explicit, commented allowlist of the current exceptions so that only **new**
offenders fail, and each has been mutation-checked (break the rule → confirm red → restore).
