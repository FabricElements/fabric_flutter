# The agent interface

This document is the practical guide to the `fabric_flutter` agent interface: how an app
turns it on, how a widget becomes agent-ready, and exactly what every built-in command
accepts and returns.

It complements [`doc/agent-bridge-protocol.md`](agent-bridge-protocol.md), which specifies
the wire protocol, the authentication envelope, the transports, and the safety controls.
Read that document before exposing the bridge outside a trusted process; read this one to
build against it.

Everything below is implemented in:

| File | Contents |
| --- | --- |
| `lib/helper/agent/agent_bridge.dart` | `AgentBridge` — configuration and the `handle` dispatcher |
| `lib/helper/agent/agent_element_binding.dart` | `AgentElement` — the widget that publishes an element |
| `lib/helper/agent/agent_element.dart` | `AgentElementHandle` — the live handle behind an element |
| `lib/helper/agent/agent_builtin_commands.dart` | The ten built-in commands |
| `lib/serialized/agent_element_snapshot.dart` | `AgentElementType` and `AgentElementSnapshot` |

---

## 1. What `AgentBridge` is

`AgentBridge` is a **transport-agnostic dispatcher**. It takes a decoded request map and
returns a decoded response map, so a socket server, a JavaScript interop entry point, or an
in-process test can all drive it without any protocol change. It performs no networking and
no access control of its own.

It is **disabled by default**. Until a host opts in, every request answers with the
`disabled` error code.

```dart
AgentBridge.instance.configure(
  enabled: true,
  appName: 'My App',
  appVersion: '1.0.0',
  routes: [AgentRouteInfo(name: '/dashboard', title: 'Dashboard')],
);
```

`configure` is additive: every parameter is optional and only the supplied values change,
so it can be called repeatedly — for example to enable the bridge after the host has
finished registering its own commands. Built-in commands are installed unless
`registerBuiltInCommands: false` is passed, and an identifier already present in the
registry is never overwritten, which is how a host specializes a built-in command: register
your own version first.

| `configure` parameter | Type | Effect |
| --- | --- | --- |
| `enabled` | `bool?` | Whether the bridge serves requests. Defaults to `false`. |
| `appName` | `String?` | Published by `describe` and `ping`. |
| `appVersion` | `String?` | Published by `describe` and `ping`. |
| `routes` | `List<AgentRouteInfo>?` | Published by `describe` so an agent knows where it can navigate. |
| `authorizer` | `AgentAuthorizer?` | Decides whether each request may run. Defaults to `AgentDenyAllAuthorizer`. |
| `commandTimeout` | `Duration?` | How long a single `invoke` may run. Defaults to 30 seconds. |
| `registerBuiltInCommands` | `bool` | Installs the built-ins. Defaults to `true`. |

`AgentBridge.instance` is the shared singleton a transport reaches without a
`BuildContext`. `AgentBridge()` builds an isolated bridge with its own registry, element
index, and navigator observer, which is what tests use. `reset()` restores the
unconfigured, disabled state and clears the registry, routes, and authorizer; the element
index is left alone because widgets own its lifecycle.

### Methods

Requests are `{ "id", "method", "params" }` and responses are `{ "id", "ok": true,
"result": {...} }` or `{ "id", "ok": false, "error": { "code", "message" } }`.

| Method | Result |
| --- | --- |
| `ping` | `{ pong: true, app, version }` |
| `describe` | `{ app, version, routes, commands }` — shaped to map 1:1 onto MCP tool definitions |
| `state` | `{ route, path, params, elements, semanticsEnabled }` |
| `invoke` | The invoked command's own return value |

`invoke` takes `commandId` (required), a nested `params` object, and an optional
`timeoutMs` that shortens the bridge's `commandTimeout` for that one call.

Error codes are a closed set: `unauthorized`, `not_found`, `invalid_params`, `disabled`,
and `failed`. A malformed frame never throws — it always produces a well-formed error
response.

### `ensureSemanticsOnWeb`

Flutter web does not build the semantics DOM until accessibility is explicitly enabled.
Without it, an external agent reading the page through the accessibility tree sees an empty
tree.

```dart
AgentBridge.instance.ensureSemanticsOnWeb = true;
AgentBridge.instance.configure(enabled: true, appName: 'My App');
```

When `true` and the bridge is enabled on the web, the bridge acquires a `SemanticsHandle`
and holds it; the handle is released when the bridge is disabled or `reset()`. Toggling the
flag while the bridge is running takes effect immediately. On native platforms it is a
no-op, because semantics are always enabled there.

`state` and `screen_state` report `semanticsEnabled` so an agent can verify the tree is
populated before it starts reading. `AgentBridge.debugIsWebOverride` (test-only) overrides
`kIsWeb` so the web path can be exercised under `flutter test`.

---

## 2. `AgentElement` and `automationKey`

`automationKey` is a **single identity** across four surfaces, so an agent, an
accessibility tool, and a test all refer to the same element by the same key:

| Surface | Consumer | Reads the key from |
| --- | --- | --- |
| Agent registry id | `AgentElementIndex` | `id` of the registered element |
| Semantics identifier | `Semantics.identifier` | `find.bySemanticsIdentifier(key)` |
| Web DOM attribute | `flt-semantics-identifier` | the browser / DOM queries |
| Test finder | `find.bySemanticsIdentifier(key)` | the same semantics node |

`AgentElement` is the widget that publishes a subtree to the live index. It applies the
identifier as a fold that **merges into the child's existing semantics node** rather than
introducing a new one, so the accessibility tree is unchanged. When `id` is `null` or
empty, nothing is registered and no identifier is applied — wrapping an unkeyed widget is
free.

```dart
AgentElement(
  id: widget.automationKey,
  type: AgentElementType.button,
  label: widget.semanticsLabel,
  hint: widget.semanticHint,
  enabledGetter: () => isActionable,
  activator: isActionable ? _activate : null,
  child: button,
);
```

| `AgentElement` parameter | Purpose |
| --- | --- |
| `child` | The subtree published to the index. |
| `id` | The element identifier, normally the widget's `automationKey`. `null`/empty is a pass-through. |
| `type` | `AgentElementType` classification. Defaults to `other`. |
| `label` | Mirrors `semanticsLabel`. |
| `hint` | Mirrors `semanticHint`. |
| `valueGetter` | Reads the current value; `null` when the element carries none. |
| `enabledGetter` | Reports whether the element accepts interaction. Defaults to `true`. |
| `visibleGetter` | Reports whether the element is rendered. Defaults to mounted **and** its route is current **and** its subtree is not muted. |
| `setter` | Applies a value exactly as user input would. `null` for elements that cannot be set. |
| `activator` | Activates the element exactly as a tap would. `null` for elements that cannot be tapped. |
| `validatorFn` | Runs the element's validator on a raw value and returns any error. |
| `errorGetter` | Returns the current validation error text, or `null`. |
| `focusNode` | The node `element.focus` moves to. When `null`, the first focusable descendant is used. |
| `semanticActions` | Named callbacks exposed as custom semantics actions (see §5). |
| `index` | Overrides the index the element registers in. Tests use this for isolation. |
| `applySemanticsIdentifier` | Defaults to `true`. Set `false` when the caller already places the identifier elsewhere. |
| `container` | Defaults to `true`; a bare identifier is itself a semantics boundary. |
| `explicitChildNodes` | Defaults to `false`. Pass `true` when the wrapped component already used it, so `label`/`hint` stay on the same node as the identifier. |

The registered entry is created on mount, refreshed whenever the owning widget rebuilds or
the enclosing route becomes current or covered, and removed on dispose. Registration is
passive: it never rebuilds the widget tree and never touches the accessibility tree.

### `AgentElementType`

The wire values are snake_case so the payload reads naturally from other languages.

| Value | Wire value | Meaning |
| --- | --- | --- |
| `button` | `button` | Activates an action when tapped. |
| `textInput` | `text_input` | Edits a free-form or formatted text value. |
| `dropdown` | `dropdown` | Selects one value from a closed list of options. |
| `checkbox` | `checkbox` | Toggles between `true` and `false`. |
| `radio` | `radio` | Selects one value from a mutually exclusive group. |
| `datePicker` | `date_picker` | Selects a date, time, or combined value. |
| `text` | `text` | Presents read-only content. |
| `image` | `image` | Presents an image or avatar. |
| `navigation` | `navigation` | Provides navigation, such as a scaffold or menu entry. |
| `other` | `other` | Does not fit any other category. |

### The element snapshot

`read_value` and the `elements` list in `state` return an `AgentElementSnapshot`:

```json
{
  "id": "home_form_input_email",
  "type": "text_input",
  "label": "Email",
  "hint": "Enter the address you signed up with",
  "value": "ada@example.com",
  "enabled": true,
  "visible": true,
  "error": null,
  "actions": ["Clear"]
}
```

`value` is normalized to a JSON-safe primitive: `DateTime` becomes an ISO-8601 string,
`TimeOfDay` becomes a zero-padded `HH:mm` string, an `Enum` becomes its name, and anything
else falls back to `toString`. `actions` lists the labels of the custom semantics actions
available on the element, or is `null` when there are none.

---

## 3. Built-in commands

`AgentBridge.configure` installs ten commands. They give an agent the same reach a human
user has: navigate anywhere, read the current screen, set any indexed input, tap any
indexed button, and synchronize on a condition. Host applications register their own domain
commands alongside them in the same `AgentRegistry`.

Every command that addresses an element takes `elementId`, which is the element's
`automationKey`. An unknown id fails with `not_found`.

### `navigate`

Opens a named route. Use the route names published by `describe`.

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `route` | string | yes | Named route to open, for example `/dashboard`. |
| `params` | object | no | Arguments passed to the route. |
| `replace` | boolean | no | Replaces the current route instead of pushing on top of it. Defaults to `false`. |

Result: `{ "route": "/dashboard", "replaced": false }`

Fails with `failed` when no navigator is available — assign `AppGlobal.navigatorKey` to
`MaterialApp.navigatorKey`.

### `set_value`

Sets the value of an indexed input exactly as user input would, including validation and
listener notification. After the value is applied the element's own validator is run (when
one is registered) and the result reports whether the new value passes.

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `elementId` | string | yes | Identifier of the element, matching its `automationKey`. |
| `value` | any | no | New value. Any JSON primitive is accepted; `null` clears the field. |

Result: `{ "id": "home_form_input_email", "value": "ada@example.com", "valid": true, "error": null }`

The command reveals and focuses the element before setting it. It fails with `failed` when
the element does not accept a value or is disabled.

### `tap`

Activates an indexed button or tappable element. It tries `ActivateIntent` through the
Flutter `Actions` system first — the same path keyboard activation (Enter / Space) takes,
so the standard enablement checks run — and falls back to the element's own `activator`
callback when no `ActivateIntent` handler is registered.

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `elementId` | string | yes | Identifier of the element, matching its `automationKey`. |
| `action` | string | no | Label of a custom semantics action to invoke instead of the default tap. Labels are localized (e.g. `Clear` / `Borrar`) and match the `actions` list in the element snapshot. |

The result reports which path ran:

```json
{ "id": "home_form_input_email", "method": "actions", "activated": true }
```

| `method` | Meaning |
| --- | --- |
| `custom_action` | The named `action` was invoked; the result also carries `"action": "<label>"`. |
| `actions` | An `ActivateIntent` handler ran. |
| `activator` | The element's own `activator` callback ran. |

Fails with `not_found` when the element has no such custom action, and with `failed` when
the element is disabled or cannot be tapped.

### `read_value`

Reads the current state of a single indexed element.

| Param | Type | Required |
| --- | --- | --- |
| `elementId` | string | yes |

Result: the full `AgentElementSnapshot` JSON shown in §2, including `error` from the last
validation.

### `wait_for`

Waits until an element or route reaches the requested condition, so an agent can
synchronize without polling screenshots.

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `elementId` | string | one of the two | Element to watch. |
| `route` | string | one of the two | Route name to wait for. |
| `condition` | enum | no | `visible`, `absent`, `enabled`, `disabled`, or `value`. Defaults to `visible`, or to `value` when an expected value is supplied. |
| `value` | any | no | Expected value, compared as a string. Implies the `value` condition. |
| `timeoutMs` | integer | no | Milliseconds to wait before failing. Defaults to `5000`. |

Result: `{ "matched": true, "condition": "visible", "waitedMs": 132 }`

Supplying neither `elementId` nor `route` fails with `invalid_params`, as does an
unrecognized `condition`. Exceeding the timeout fails with `failed`. The condition is
re-evaluated every 50 ms.

### `screen_state`

Returns the active route and every element currently indexed on it. Equivalent to the
`state` method. Takes no parameters.

Result: `{ "route", "path", "params", "elements", "semanticsEnabled" }`

### `list_commands`

Lists every registered command, optionally filtered by category.

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `category` | string | no | Restricts the result to a single command category. |

Result: an array of `AgentCommandInfo` objects — `{ id, title, description, category,
params, requiresRole }`. The built-in categories are `navigation`, `interaction`,
`inspection`, and `synchronization`.

### `element.reveal`

Scrolls the indexed element into view, staying with it through layout settles.

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `elementId` | string | yes | Identifier of the element, matching its `automationKey`. |
| `alignment` | number | no | Where the element lands in the viewport: `0` at the leading edge, `1` at the trailing edge. Defaults to `0.1`. |

Result: `{ "id": "home_list_item_42", "revealed": true }`

`revealed` is `false` when the element is unmounted or has no enclosing scrollable.

### `element.focus`

Moves input focus to the element, or its first focusable descendant.

| Param | Type | Required |
| --- | --- | --- |
| `elementId` | string | yes |

Result: `{ "id": "home_form_input_email", "focused": true }`

`focused` is `false` when the element has no `focusNode` and no descendant accepts focus.

### `form.submit`

Validates the `Form` that contains the indexed element. It does **not** submit — it only
validates.

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `elementId` | string | yes | Identifier of any element inside the target `Form`. |

Result when every field passes: `{ "valid": true }`

Result when a field fails: `{ "valid": false, "errors": { "home_form_input_email": "Enter a valid email address" } }`

`errors` is keyed by the failing element's `automationKey`, and is omitted entirely when
the form is valid. Fails with `failed` when the element has no widget context or is not
inside a `Form`.

---

## 4. Revealing items in lazy and nested lists

`Scrollable.ensureVisible` runs once, so it misses targets whose surroundings keep changing
after the call: content that loads asynchronously above the target, images that finish
decoding, expandable tiles that open. Reveal here means "scroll the target to an alignment,
then re-check until the layout stops moving".

`ScrollReveal.reveal` is the stateless helper behind `element.reveal`. It works through
nested scrollables, backs off as soon as the user scrolls or the target unmounts, and jumps
instead of animating when the platform asks for reduced motion.

```dart
final revealed = await ScrollReveal.reveal(
  sectionKey.currentContext!,
  alignment: 0.1,                              // 0 = leading edge, 1 = trailing edge
  settle: const Duration(milliseconds: 1500),  // give up after this long
  quiet: const Duration(milliseconds: 500),    // ...or once it has held still this long
);
```

It returns `false` when the target unmounted, has no enclosing scrollable, the user took
over, or a newer reveal cancelled this one.

For items that do not exist yet — a row on a page that has not loaded, a step inside a
collapsed tile — pass a `RevealController` to the component's existing `controller:`
parameter and call `RevealController.reveal`, which maps the target onto that component's
own layout:

| Component | `reveal` target | Reveals |
| --- | --- | --- |
| `PaginationContainer` | an `int` index, or a predicate `bool Function(dynamic item)` | that item, loading further pages as needed |
| `StepperExtended` | a step `int` index, or `RevealTarget(target: index, within: fieldKey)` | the step, or a field inside it when `within` is a mounted `GlobalKey` |
| `ExpansionTable` | a `TableRowData` or a row `int` index | that row, and — with `RevealTarget(column: 1)` — a column of it |

```dart
await contactTableController.reveal(RevealTarget(target: contactRow, column: 1));
await planStepperController.reveal(3, alignment: 0.1);
```

Each call returns `true` only when the target actually ended up in view. A controller
attached to no mounted component — or an out-of-range index — returns `false` without side
effects. Only one reveal runs at a time: starting a new one cancels the one in flight,
which then returns `false`.

---

## 5. `semanticActions` and `announce()`

### `semanticActions`

`AgentElement.semanticActions` exposes named callbacks as
`Semantics.customSemanticsActions` on the same merged node as the identifier, so assistive
technology and the agent see the same verbs. Each label maps to a `VoidCallback` that the
agent invokes through the `tap` command's `action` parameter.

```dart
AgentElement(
  id: widget.automationKey,
  type: AgentElementType.textInput,
  semanticActions: <String, VoidCallback>{
    locales.get('label--clear'): _clear,
  },
  child: field,
);
```

Only expose actions the UI already offers — do not invent new ones. Labels are localized,
so an agent should read the `actions` list from the element snapshot rather than hard-code
an English label. When `semanticActions` is `null` or empty, no custom actions are added
and the semantics tree is unchanged.

### `announce()`

`announce` sends a screen-reader announcement only when the platform supports it, keeping
the `MediaQuery.supportsAnnounceOf` guard in one place instead of repeating it at every
call site.

```dart
announce(context, locales.get('alert--saved'));
```

It returns early when the context is no longer mounted, when the message is empty, or when
the ambient `MediaQuery` reports that announcements are unsupported. A missing
`MediaQuery` is treated as supported. `assertiveness` defaults to `Assertiveness.polite` so
the announcement waits for the screen reader to finish speaking; use
`Assertiveness.assertive` only for urgent, interrupting messages.

Call it from an event handler, never from `build`, so the announcement fires once per real
state change. For a message that must be re-announced when the same text recurs, use
`LiveAnnouncer` with an `announcementTag` instead.

---

## 6. Testing with `find.bySemanticsIdentifier`

Because `automationKey` is the semantics identifier, a widget test locates an element with
the same key an agent uses:

```dart
testWidgets('saves the profile', (tester) async {
  // Arrange
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const MaterialApp(home: ProfilePage()));

  // Act
  await tester.enterText(
    find.bySemanticsIdentifier('profile_form_input_name'),
    'Ada',
  );
  await tester.tap(find.bySemanticsIdentifier('profile_toolbar_button_save'));
  await tester.pumpAndSettle();

  // Assert
  expect(find.bySemanticsIdentifier('profile_banner_text_saved'), findsOneWidget);
  handle.dispose();
});
```

`tester.ensureSemantics()` is required: the identifier lives on a semantics node, and the
semantics tree is not built otherwise.

To assert against the agent index directly, reset the shared index around each test and
read the handle:

```dart
final index = AgentElementIndex.instance;

setUp(index.reset);
tearDown(index.reset);

testWidgets('registers the key', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
  expect(index.contains('profile_toolbar_button_save'), isTrue);
  expect(index.handle('profile_toolbar_button_save')?.type, AgentElementType.button);
});
```

For a test that must not touch the shared index at all, pass `AgentElement(index: ...)`
with a local `AgentElementIndex()`, or build an isolated `AgentBridge()`.

---

## 7. Adding a command

A command pairs a serializable description with a handler. The description is what
`describe` publishes; the handler never crosses the transport boundary.

```dart
AgentBridge.instance.registry.register(
  AgentCommand.define(
    id: 'archive_order',
    title: 'Archive order',
    description: 'Moves an order to the archive.',
    category: 'orders',
    requiresRole: 'admin',
    params: [AgentParam(name: 'orderId', required: true)],
    handler: (context) => archiveOrder(context.require<String>('orderId')),
  ),
);
```

- `context.require<T>(name)` throws `invalid_params` when the value is missing or is not a
  `T`; `context.optional<T>(name)` returns `null` when absent.
- `context.meta` carries values attached by the authorizer, such as the resolved principal.
- Throw `AgentException.notFound`, `AgentException.invalidParams`, or
  `AgentException.failed` to control the error code the caller sees. Any other thrown
  object is reported as `failed`.
- The returned value must be JSON-serializable, because it is placed directly into the
  `result` field of the response.
- `requiresRole` is only carried through to the injected authorizer; the registry performs
  no access checks of its own.

Registering an id that already exists throws unless `override: true` is passed. Because
`configure` never overwrites an existing id, registering your own version of a built-in
command before calling `configure` is how you specialize it.

---

## 8. MCP facade

`AgentMcpAdapter` (`lib/helper/agent/agent_mcp_adapter.dart`) is an MCP JSON-RPC 2.0
facade over the existing `AgentBridge`. Any MCP client can drive a fabric_flutter
application through the bridge transports that already exist — no new network server, no
new authentication layer. The adapter reuses the bridge's configured `AgentAuthorizer`
exactly as `AgentBridge.handle` does.

### 8.1 Protocol version

The adapter speaks MCP protocol version `2025-06-18` and JSON-RPC 2.0. It detects MCP
frames by the presence of `"jsonrpc": "2.0"` in the request map.

### 8.2 Method mapping

| MCP method | Bridge method | Notes |
| --- | --- | --- |
| `initialize` | — | Returns `serverInfo` and `capabilities` |
| `ping` | `ping` | Returns `{}` |
| `tools/list` | `describe` | Each bridge command becomes an MCP tool with JSON Schema |
| `tools/call` | `invoke` | Maps MCP tool name back to bridge command id |
| `notifications/*` | — | Returns `null` (no response) |

### 8.3 Name mapping

MCP tool names must match `^[a-zA-Z0-9_-]{1,64}$`. Dots in bridge command identifiers
are replaced with double underscores:

| Bridge command id | MCP tool name |
| --- | --- |
| `element.reveal` | `element__reveal` |
| `element.focus` | `element__focus` |
| `form.submit` | `form__submit` |
| `set_value` | `set_value` (unchanged) |

The reverse mapping is applied on `tools/call` so the bridge receives the original dotted
identifier. `screen_state` is a built-in command and appears as a tool — it is not
duplicated.

### 8.4 Error mapping

| Bridge error code | MCP response |
| --- | --- |
| `not_found` | Tool result with `isError: true` |
| `invalid_params` | Tool result with `isError: true` |
| `failed` | Tool result with `isError: true` |
| `unauthorized` | JSON-RPC error `-32001` with `data.code: "unauthorized"` |
| `disabled` | JSON-RPC error `-32002` with `data.code: "disabled"` |
| Unknown tool | JSON-RPC error `-32602` (invalid params) |
| Unknown method | JSON-RPC error `-32601` |
| Malformed request | JSON-RPC error `-32600` |

Tool execution errors (`not_found`, `invalid_params`, `failed`) are reported as successful
tool results with `isError: true`, not as protocol errors. This follows the MCP convention
that a tool that runs and fails is still a successful tool execution.

### 8.5 Authentication

The adapter passes through the same auth envelope the bridge expects. A bearer token
travels in the MCP `params._meta.token` field and is injected into the reserved `auth`
request parameter before the bridge sees it, matching the envelope described in
[`doc/agent-bridge-protocol.md`](agent-bridge-protocol.md).

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "tools/call",
  "params": {
    "name": "set_value",
    "arguments": { "elementId": "name_input", "value": "Hello" },
    "_meta": { "token": "******" }
  }
}
```

The `_meta` object is stripped from the bridge request; only the token is forwarded.

### 8.6 Where MCP is served

MCP is served by `AgentDispatcher`, so **every transport** — the native WebSocket/POST
server, the web `window.fabricAgentBridge` entry point, and `AgentInProcessTransport` —
speaks it with no per-transport code. A frame carrying `"jsonrpc": "2.0"` is routed to the
dispatcher-owned adapter (`AgentDispatcher.mcp`); legacy frames (no `jsonrpc`) are
unchanged. The adapter's bridge calls re-enter the dispatcher's normal path, so MCP
traffic gets the request size limit, the rate limit, the audit log (an MCP `tools/call`
is audited as an `invoke` of the mapped command), principal resolution, and the
transport credential (`Authorization` header or `token`, used when `params._meta.token`
is absent).

The tool-name map is built from `describe`. A `tools/call` for a name not yet known
refreshes the map once, so a client need not call `tools/list` first.

### 8.7 Notifications

An MCP notification (a frame without `id`) has no response. `AgentDispatcher.handle`
and `handleJson`, and `AgentInProcessTransport.send` and `sendJson`, return `null`; the
WebSocket server sends no frame, the POST server answers `202 Accepted` with an empty
body, and the web entry point resolves with `null`. A transport must never send a frame
for a `null` result.
