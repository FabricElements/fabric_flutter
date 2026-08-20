# Agent bridge protocol

This document specifies the wire protocol, the authentication envelope, the
transports, and the safety controls of the `fabric_flutter` agent bridge. It is
the contract an external agent — an MCP server, a cloud workflow, a browser
automation client, an integration test — implements to drive a Flutter
application the way a person can.

The bridge is **disabled by default**, **performs no login of its own**, and
adds **no dependencies**.

---

## 1. Layers

| Layer | Type | Responsibility |
| --- | --- | --- |
| Dispatcher | `AgentBridge` | Decodes a request map, resolves the method, runs the command, encodes a response map. Transport agnostic. |
| Access control | `AgentAuthorizer` → `AgentTokenAuthorizer` | Verifies the bearer token and enforces `AgentCommand.requiresRole`. |
| Safety + audit | `AgentDispatcher` | Request size cap, rate limiting, principal attribution, audit records. |
| Transport | `AgentTransport` → `AgentInProcessTransport`, `AgentBridgeServer` | Framing only: decode a payload, call the dispatcher, encode the reply. |

Every transport funnels through `AgentDispatcher`, so a new transport cannot
widen the attack surface by accident.

---

## 2. Envelope

### Request

```json
{
  "id": "1",
  "method": "invoke",
  "params": {
    "auth": "Bearer <access token>",
    "commandId": "set_value",
    "params": { "elementId": "home_form_input_name", "value": "Ada" },
    "timeoutMs": 5000
  }
}
```

* `id` correlates the reply. Any string; it is echoed back verbatim.
* `method` is one of `describe`, `state`, `invoke`, `ping`.
* `params` holds the method arguments. For `invoke`, `commandId` names the
  command and the nested `params` object holds the command's own arguments.

### Response

```json
{ "id": "1", "ok": true, "result": {} }
```

```json
{ "id": "1", "ok": false, "error": { "code": "unauthorized", "message": "…" } }
```

### Error codes

| Code | Meaning |
| --- | --- |
| `unauthorized` | The token is missing, invalid, or expired, or the principal lacks the command's role. |
| `not_found` | Unknown method, command, or element. |
| `invalid_params` | Malformed JSON, a non-object payload, a payload above the size cap, or a missing/invalid parameter. |
| `disabled` | The bridge has not been enabled, or the in-process transport has been stopped. |
| `failed` | The command threw, exceeded its timeout, or the caller exceeded its rate limit. |

A malformed frame never produces an exception or a broken reply: it always
produces a well-formed error response.

---

## 3. Where the bearer token goes

**The token travels in the reserved `auth` field of `params`.**

```json
{
  "id": "1",
  "method": "invoke",
  "params": {
    "auth": "Bearer eyJhb…",
    "commandId": "tap",
    "params": { "elementId": "home_toolbar_button_save" }
  }
}
```

* The `Bearer ` prefix is optional and case insensitive.
* `params.auth` is reserved: it is *not* passed to command handlers, which
  receive only `params.params`.
* It is never written to the audit log.

Transports that carry their own credential normalize it into the same field
before dispatching, so the authorizer only ever looks in one place:

| Transport | Accepted transport-level credential |
| --- | --- |
| Native HTTP / WebSocket | `Authorization: Bearer <token>` header, or `?token=<token>` on the handshake URL (browsers cannot set headers on a WebSocket handshake). |
| Web (JS interop) | None — the browser cannot attach headers to the call, so use `params.auth`. |
| In-process | Optional `token:` argument on `send` / `sendJson`. |

A token already present in `params.auth` always wins over a transport-level
credential, so one connection can act for several principals.

### Where the token comes from

The bridge implements **no** login, token minting, or refresh. An agent obtains
a normal OAuth 2.0 access token through the host's existing authorization-code
flow (consent screen, `POST /auth/token`, refresh token) and presents it here.
The application verifies it by supplying an `AgentTokenVerifier`:

```dart
typedef AgentTokenVerifier = FutureOr<AgentPrincipal?> Function(String token);
```

Returning `null` — or throwing — denies the request. The reason is never
forwarded to the caller.

---

## 4. Authorization

`AgentTokenAuthorizer` resolves the token to an `AgentPrincipal`
(`id`, `role`, `groups`, `scopes`, `expiresAt`, `claims`) through
`AgentPrincipalResolver`, which caches a verified principal for five minutes by
default and never caches a rejection.

Role enforcement compares `AgentCommand.requiresRole` against the principal, in
order:

1. `role == 'admin'` passes everything (`AgentTokenAuthorizer.superRole`).
2. An exact match against `principal.role`.
3. A requirement written `<group>-<role>` passes when `principal.groups[group]`
   is that role, or `admin`.
4. A bare requirement passes when the principal holds that role in any group.

Pass a custom `roleCheck` to replace those rules entirely.

Discovery is gated separately, because `ping` and `describe` resolve to no
command:

| Flag | Default | Effect |
| --- | --- | --- |
| `requireAuthenticationForDiscovery` | `true` | `ping` and `describe` need a token. |
| `requireAuthenticationForState` | `true` | `state` needs a token. |

On approval the principal is forwarded to the command handler through
`AgentCommandContext.meta` under the keys `principal`, `principalId`, `role`,
and `groups`.

> Client-side role checks are a UX and blast-radius control. Authorization is
> still enforced server-side by Firestore rules and Cloud Functions.

---

## 5. Safety controls

| Control | Default | Where |
| --- | --- | --- |
| Kill switch | Disabled | `AgentBridge.configure(enabled: …)` — every request answers `disabled` until a host opts in. |
| Authentication required | On | `AgentBridgeServerOptions.requireAuth`; starting a transport throws `ArgumentError` when no verifier is supplied and the bridge still carries `AgentAllowAllAuthorizer`. |
| Loopback only | `127.0.0.1` | `AgentBridgeServerOptions.host`. |
| Max request size | 64 KiB | `AgentBridgeServerOptions.maxRequestBytes`. |
| Max connections | 4 | `AgentBridgeServerOptions.maxConnections`. |
| Rate limit | 60 requests / minute | `maxRequestsPerWindow`, `rateLimitWindow`; bucketed per principal, or per connection when anonymous. |
| Command timeout | 30 s | `AgentBridge.configure(commandTimeout: …)`, per request `params.timeoutMs`. |

---

## 6. Audit log

Every `invoke` produces one `AgentAuditRecord`, whether it succeeded or failed,
delivered to the injected `AgentAuditSink`:

```json
{
  "timestamp": "2026-08-20T21:02:40.033Z",
  "requestId": "1",
  "principalId": "user-member",
  "commandId": "set_value",
  "outcome": "success",
  "durationMs": 1,
  "params": { "elementId": "<string:20>", "value": "<string:3>" },
  "errorCode": null,
  "transport": "in_process"
}
```

* `principalId` is `anonymous` when the caller presented no verifiable token.
* `outcome` is `success` or `failure`; `errorCode` carries the protocol code on
  failure.
* **`params` never contains a value.** Each value is replaced by a type and size
  summary (`<string:3>`, `<num>`, `<bool>`, `<list:2>`, `<map:1>`, `<null>`),
  and a key that looks like a credential (`auth`, `token`, `accessToken`,
  `password`, `apiKey`, `secret`, …, matched case-insensitively ignoring `_`,
  `-`, and `.`) is replaced by `<redacted>` with no size at all, so not even a
  token's length leaks.
* A sink that throws is caught and reported; auditing can never fail a request.

`describe`, `state`, and `ping` are not audited — they mutate nothing.

---

## 7. Transports

### In-process

```dart
final transport = await AgentInProcessTransport.start(
  bridge: AgentBridge.instance,
  verifier: myVerifier,
  auditSink: myAuditSink,
);
final response = await transport.send(
  {'id': '1', 'method': 'ping'},
  token: accessToken,
);
await transport.stop();
```

Used by tests, embedded automation, and hosts that already own a channel
(a platform channel, an MCP stdio server, a callable function).

### Native — WebSocket and HTTP on one port

```dart
final server = await AgentBridgeServer.start(
  options: const AgentBridgeServerOptions(port: 8757),
  verifier: myVerifier,
  auditSink: myAuditSink,
);
```

* WebSocket: `ws://127.0.0.1:8757/` — one JSON request per text frame, one JSON
  response per reply.
* HTTP: `POST http://127.0.0.1:8757/` — the body is one JSON request.
* Pass `port: 0` for an ephemeral port and read `server.port`.
* Oversized bodies answer `413`, excess connections answer `503`, a method other
  than `POST` answers `405`.

### Web — JavaScript entry point

```js
const response = await window.fabricAgentBridge({
  id: '1',
  method: 'describe',
  params: { auth: 'Bearer <access token>' },
});
```

A page cannot listen on a socket, so the transport is inverted: the bridge
installs a callable property on `window` (renamed with
`AgentBridgeServerOptions.jsBindingName`) that Playwright, Puppeteer, a CDP
client, an extension, or the console can call. It accepts a JavaScript object or
a JSON string, always resolves, and resolves with a plain object.

---

## 8. Methods and built-in commands

| Method | Result |
| --- | --- |
| `ping` | `{ pong, app, version }` |
| `describe` | `{ app, version, routes, commands }` — shaped to map 1:1 onto MCP tool definitions. |
| `state` | `{ route, path, params, elements }` |
| `invoke` | The command's own return value. |

Built-in commands: `navigate`, `set_value`, `tap`, `read_value`, `wait_for`,
`screen_state`, `list_commands`. Elements are addressed by their
`automationKey`, which is the same identifier the accessibility layer publishes.

---

## 9. Host bootstrap

```dart
AgentBridge.instance.configure(
  enabled: true,
  appName: 'Furcata',
  appVersion: packageInfo.version,
  routes: myRoutes,
);

await AgentBridgeServer.start(
  verifier: (token) async => myBackend.principalFor(token),
  auditSink: (record) => myAuditCollection.add(record.toJson()),
  options: const AgentBridgeServerOptions(port: 8757),
);
```

And wire the navigator so route reporting and `navigate` work:

```dart
MaterialApp(
  navigatorKey: AppGlobal.navigatorKey,
  navigatorObservers: [AgentNavigatorObserver.instance],
);
```
