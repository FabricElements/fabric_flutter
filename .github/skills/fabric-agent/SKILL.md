---
name: fabric-agent
description: Use when making a fabric_flutter widget agent-ready or when adding a built-in agent command — wrapping a widget with AgentElement, choosing an automationKey or AgentElementType, wiring semanticActions, announcing state changes, or registering a new command on AgentBridge. Load on any mention of AgentBridge, AgentElement, automationKey, agent-ready widgets, or the agent bridge protocol.
---

# Making fabric_flutter widgets agent-ready

The full reference is [`doc/agent.md`](../../../doc/agent.md). Read it before changing anything
here; this skill is the short version. The wire protocol (envelopes, transports, auth, audit) is in
[`doc/agent-bridge-protocol.md`](../../../doc/agent-bridge-protocol.md).

## The one rule

**`automationKey` is the single identity.** One key is simultaneously the agent registry id, the
`Semantics.identifier`, the `find.bySemanticsIdentifier` test finder, and the web
`flt-semantics-identifier` DOM attribute. Never add a second, separate `Semantics` identifier for
the agent — that creates two identities that drift apart.

## Making a widget agent-ready

1. **Wrap the interactive widget in `AgentElement`** (`lib/helper/agent/agent_element_binding.dart`),
   or accept an `automationKey` parameter and forward it if the widget already wraps itself.
   `AgentElement` adds no `Semantics` node — it folds its identifier into the child's node, so the
   accessibility tree is unchanged.
2. **Pass `id`** (the `automationKey`). A null or empty `id` makes `AgentElement` a pass-through:
   it registers nothing and adds no identifier. Follow the naming convention
   `[RouteName]_[ContextBlock]_[ComponentType]_[ActionOrId]`, lowercase snake case.
3. **Pick the right `type`** (`AgentElementType`): `button`, `text_input`, `dropdown`, `checkbox`,
   `radio`, `date_picker`, `text`, `image`, `navigation`, `other`. The type is what an agent uses to
   decide how to interact; `other` is the fallback, not the default choice.
4. **Supply the getters and setters the type implies.** A `text_input` needs `valueGetter` and
   `setter`; a `button` needs `activator` (or relies on `ActivateIntent`). Add `enabledGetter`,
   `visibleGetter`, `errorGetter`, and `validatorFn` where they carry real information — an agent
   reads them to decide whether an action is possible and why it failed.
5. **Add `semanticActions`** for actions that are not the element's primary activation (a "Clear"
   button inside a text field, a row-level "Delete"). Each entry is a label mapped to a
   `VoidCallback`; they surface as `customSemanticsActions` and are invoked by `tap` with the
   `action` parameter.
6. **Call `announce()`** (`lib/helper/announce.dart`) when state changes in a way that is not
   visible in the element tree — a save that succeeded, a background refresh that failed. It is a
   no-op when the platform does not support announcements, so it is always safe to call.
7. **Add a semantics test** at `test/component/<name>_semantics_test.dart` asserting the label,
   identifier, and hint appear in the semantics tree. Use `tester.ensureSemantics()` and
   `find.bySemanticsIdentifier(key)`.

If the widget lives in a lazy or nested list, also make it revealable — see
[`doc/agent.md` §4](../../../doc/agent.md) for `ScrollReveal.reveal` and `RevealController`.

## Adding a built-in command

1. Define it with `AgentCommand.define({id, title, description, category, params, requiresRole,
   handler})` in `lib/helper/agent/agent_builtin_commands.dart`.
2. Declare every parameter as an `AgentParam` (`lib/serialized/agent_param.dart`) with an explicit
   `AgentParamType` — `string`, `number`, `integer`, `boolean`, `object`, or `array`. Read them in
   the handler through `AgentCommandContext` (`require<T>` for mandatory, `optional<T>` otherwise).
3. Throw `AgentException.invalidParams` / `.notFound` / `.unauthorized` / `.failed` rather than
   returning an error shape; the bridge converts them into the response envelope.
4. Return a JSON-serializable `Map<String, dynamic>` whose keys are stable — agents depend on them.
5. Register it in the built-in list so `configure(registerBuiltInCommands: true)` picks it up. A
   host that registers the same id first keeps its own version; built-ins never overwrite.
6. Document it in [`doc/agent.md` §3](../../../doc/agent.md) with its exact params and result shape,
   and add a test under `test/helper/agent/`.
