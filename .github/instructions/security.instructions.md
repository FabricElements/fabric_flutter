---
applyTo: "lib/**/*.dart, ios/**, android/**, web/**, macos/**, windows/**, linux/**"
---

# Security Instructions

These rules govern all Dart source under `lib/` and any platform directory a
future release adds. They are derived from an audit of this package and cite the
code they came from, so a change that invalidates a citation should update this
file too. General engineering practice for FabricElements shared packages lives
in `cross-repo.instructions.md`; this file is the package-specific layer.

---

## 1. The client is untrusted

`fabric_flutter` ships inside applications that run on hardware the operator does
not control. Assume the binary has been decompiled, patched, and re-signed, and
that a caller can invoke any code path with any argument in any order.

The practical consequence is that **nothing this package does is a security
control**. Every check here exists to produce a coherent user interface. The
security boundary is Firestore Security Rules, Cloud Functions, and Cloud
Storage rules in the consuming project.

Write code accordingly:

- Never gate access to data on a widget being hidden.
- Never treat a value read from a document, a claim, or a callback argument as
  proof of anything.
- Assume every query this package issues will also be issued by hand, with the
  filters removed.

---

## 2. Public-by-design keys versus genuine secrets

Do not treat these as leaks. They are published to every client by design, and
"fixing" them wastes review time and hides real findings:

- Firebase Web API keys and the rest of a `FirebaseOptions` block.
- Google Maps **browser** keys, including the one `GoogleMapsSearch` accepts as
  `apiKey` (`lib/component/google_maps_search.dart:62`) and forwards as a query
  parameter (`lib/component/google_maps_search.dart:289`). Restrict these by
  referrer, bundle id, and API in the cloud console — that is the control, not
  secrecy.
- reCAPTCHA **site** keys and OAuth **client ids**.
- The agent bridge defaults: host `127.0.0.1`, port `8757`, and the JS binding
  name (`lib/helper/agent/agent_bridge_server_options.dart`).

These are genuine secrets and must never appear in this repository, its tests,
its fixtures, or its documentation:

- Service-account JSON, private keys, and signing material.
- Server-side API keys and OAuth client **secrets**.
- App Check / attestation **debug tokens**. A debug token is a bearer credential
  whose entire purpose is to bypass attestation; publishing one silently
  disables the control for anyone who finds it.
- Any bearer token, session token, or push token captured from a real device.

At the time of writing this package contains no platform directories, so there
is no `google-services.json`, `GoogleService-Info.plist`, `AndroidManifest.xml`,
or `Info.plist` in scope. If a release adds one, re-audit it against this list.

---

## 3. Collection queries must carry an account scope

This is the rule most likely to be violated by accident, and the one with the
largest blast radius.

### Why ordering is not scoping

Firestore evaluates a `list` operation by comparing the rule against the
**query**. A rule that constrains documents by a field is only satisfied when the
query carries a matching **filter**. Ordering does restrict which documents come
back — Firestore omits documents that lack the ordered field — but it is not a
constraint the rules engine can require, and `request.query` exposes only
`limit`, `offset`, and `orderBy`.

The consequence is asymmetric and easy to miss:

> A `list` rule cannot tell a legitimate ordered read apart from an enumeration
> of the whole collection. So as long as **any** client issues an unfiltered
> collection query, the project cannot tighten `list` at all — the rule would
> break the legitimate screen and the attacker would simply issue the same query.

Tightening the rule is therefore gated on the client, which is why this belongs
in the library and not in a consuming app.

### The rule

> **Build every `user` collection query through `UserQuery`
> (`lib/helper/user_query.dart`), and express the account scope as a `where`
> filter, never as an `orderBy` alone.**

`UserQuery.scopeToField` (`lib/helper/user_query.dart:68`) applies the filter and
the matching lead ordering together, because Firestore requires the inequality
field to be the first ordering and a caller that applies only one half gets a
runtime error or an unscoped read. `UserQuery.isScoped`
(`lib/helper/user_query.dart:106`) inspects the query's filters, not its
ordering, and is the check to reach for when asserting the property in a test.

### Prefer a `get` over a `list`

A filter on `FieldPath.documentId` is still a **`list`** operation. Reading one
document by id is a **`get`**, governed by a separate rule. Splitting them lets a
project keep `allow get` open for the documents a caller may legitimately resolve
while denying `allow list` outright.

`StateUsers.fetchUsersById` (`lib/state/state_users.dart:177`) resolves a batch
with concurrent `doc(uid).get()` reads (`lib/state/state_users.dart:183`) for
exactly this reason. Both forms bill one read per returned document, so the
conversion costs nothing. **Do not reintroduce a `whereIn` filter on the document
id.**

### Current state of the call sites

| Call site | Scope |
| --- | --- |
| `lib/component/user_admin.dart:34` (`resolveUserAdminQuery`) | Filtered on `groups.<group>` when a group is supplied; **collection-wide** on `lib/component/user_admin.dart:40` when it is not. |
| `lib/helper/user_roles_firebase.dart:87` | Filtered on `roles.<group>` when a group is supplied; **collection-wide** on `lib/helper/user_roles_firebase.dart:90` when it is not. |
| `lib/state/state_users.dart:177` | Per-document `get`; not a collection query at all. |

The two collection-wide paths are deliberate and additive: removing them would
break consumers that pin this package. Both accept a caller-supplied `query`, so
a project whose rules deny unscoped listing can pass a query it has already
narrowed. **When adding a new listing, give it a scope parameter from the start
rather than adding an unscoped default that later cannot be removed.**

Note an existing inconsistency, left alone deliberately so a security change did
not silently alter a result set: `user_roles_firebase.dart` scopes on
`roles.<group>` while `user_admin.dart` and `UserRoles.roleFromData`
(`lib/helper/user_roles.dart:26`) read `groups`. `UserData.roles`
(`lib/serialized/user_data.dart:185`) is a `List<String>` and `UserData.groups`
(`lib/serialized/user_data.dart:182`) is a `Map<String, String>`. Reconcile it as
a separate, clearly-labelled change.

---

## 4. Client-side authorization is UX, never security

The package computes roles locally and hides controls with the result. Every one
of these is a presentation decision:

- `StateUser.role` (`lib/state/state_user.dart:105`) — prefers the role on the
  user document and falls back to a token claim.
- `StateUser.admin` (`lib/state/state_user.dart:102`).
- `StateUser.roleFromData` (`lib/state/state_user.dart:141`).
- `StateUser.accessByRole` (`lib/state/state_user.dart:215`).
- `UserRoles.roleFromData` (`lib/helper/user_roles.dart:12`).
- `UserAdmin` hiding edit and remove controls for the signed-in user
  (`lib/component/user_admin.dart`), and revealing the user id only when
  `stateUser.admin` is true (`lib/component/user_admin.dart:458`).

Custom claims are read from a verified ID token, but they are read **by the
client**, and the branch that consumes them is patchable. Flipping `admin` to
`true` in a modified build reveals hidden UI and lets the app issue the
privileged call. Whether that call succeeds is decided entirely on the server.

**What a consuming project must enforce server-side:**

- Every role and group check that gates data, re-evaluated in Firestore rules or
  in the Cloud Function.
- The user-management callables this package invokes — `user-actions-add`,
  `user-actions-remove`, and `user-actions-role`
  (`lib/helper/user_roles_firebase.dart:16`, `:25`, `:37`). The client sends
  `UserData.toJson()` plus a `group`; the function must ignore every field it
  did not expect. Reset by **allow-list**, never denylist, and never let a
  caller-supplied `role`, `roles`, or `groups` map reach a write.
- `list` and `get` on the user collection, per section 3.
- Cloud Storage object access, per section 7.

---

## 5. In-flight locks on paid and side-effecting actions

A double-tap must never produce two charges, two messages, or two writes.

> **A guard set after the first `await` is not a lock.** Between the tap and that
> `await`, the event loop can deliver a second tap, and both callers see the
> pre-set value.

Set the flag **synchronously**, before any suspension point, and clear it in a
`finally`. Disable the control while it is set so the UI matches the guard.

The audited flows follow this correctly and are the pattern to copy:
`UserAddUpdate` sets `sending` before awaiting its confirm callback
(`lib/component/user_add_update.dart`), `ProfileEdit` sets `loading` before
awaiting the callable (`lib/component/profile_edit.dart`), and
`UploadImageMedia` sets `loading` before starting the upload
(`lib/component/upload_image_media.dart`). Phone verification in
`lib/view/view_auth_page.dart` guards with `loading` before dispatching, which
matters because each SMS is billed.

---

## 6. Untrusted URLs and untrusted navigation

Widgets in this package render data they did not author — table cells, chart
links, decoded JSON. Any string in that data can reach a platform handler.

> **Never pass a value to `launchUrl`, `launchUrlString`, or a WebView without
> validating its scheme against an allow-list.**

`Uri.parse` and `Uri.tryParse` are not validation: they succeed for
`javascript:alert(1)` and for `file:///etc/passwd`, and a `hasAbsolutePath` check
accepts both `file:///...` and `javascript:/x`.

Use `UrlSafety` (`lib/helper/url_safety.dart`). `UrlSafety.safeUri`
(`lib/helper/url_safety.dart:33`) enforces the `allowedSchemes` allow-list
(`lib/helper/url_safety.dart:22`) and requires a host; `UrlSafety.isSafe`
(`lib/helper/url_safety.dart:48`) decides whether to render a value as tappable
at all, so the UI never offers an action the launcher will refuse. An allow-list
is required rather than a denylist of `javascript:` and `data:`, because a
denylist is correct only until a platform adds another scheme.

Current call sites: `lib/component/expansion_table.dart`,
`lib/component/json_explorer_search.dart`, and
`lib/component/google_chart_container.dart`.

Two related hazards to keep in mind:

- `ExpansionTable` routes a `TableDataType.route` cell into
  `Navigator.pushNamed` with a backend-supplied value. Consumers must not
  register a named route that performs a privileged action without its own
  confirmation.
- `IframeMinimal` on native enables unrestricted JavaScript
  (`lib/component/iframe_minimal_native.dart:50`) and permits every navigation
  request (`lib/component/iframe_minimal_native.dart:71`). It is therefore only
  safe with a **trusted** `src`. Restricting it would break existing consumers,
  so it is documented rather than changed: treat `src` as fully trusted content,
  because script running there shares the WebView's origin and storage.

---

## 7. Cloud Storage is governed only by the consuming project

`FirebaseStorageHelper` (`lib/helper/firebase_storage_helper.dart`) reads and
writes Cloud Storage objects directly from the client — see the bucket
references at `lib/helper/firebase_storage_helper.dart:38`, `:95`, and `:231`.

There is **no application logic between the widget and the bucket**. No Cloud
Function validates the path, the content type, or the size. Whatever the client
sends is what the bucket receives, subject only to the project's Storage
Security Rules.

Consumers must therefore enforce, in Storage rules: who may write to a prefix,
the permitted content types, a maximum object size, and who may read back. Derive
object paths from validated components; never accept a caller-supplied path.

---

## 8. Errors and logging

**Errors.** Prefer a localized key over a backend string. Several flows currently
render the backend message directly — for example
`lib/component/user_admin.dart:307` and `lib/component/profile_edit.dart:301`.
Backend text is written for operators and can carry internal detail, so new code
should map to a localization key and keep the raw message for the log. Do not
swallow a failure: an empty `catch` on a paid operation reports success to the
user. `lib/state/state_api.dart:528` is the one tolerated instance, closing an
HTTP client during teardown.

**Logging.** `debugPrint` is **not** stripped from release builds. Wrap anything
diagnostic in `if (kDebugMode)`, and never log a credential, token, or full user
record. Push tokens are bearer credentials for delivering to a device: the APNS
lookup in `lib/state/state_notifications.dart` logs only that a token resolved,
never its value, and new code must do the same.

---

## 9. Before you merge

- [ ] Does a new Firestore collection query carry a `where` filter that scopes it
      to an account, or is it knowingly collection-wide and documented as such?
- [ ] Did you reach for `orderBy` where you meant a filter?
- [ ] Could this read be a `get` instead of a `list`?
- [ ] Does a new interactive control that costs money set its guard **before**
      the first `await`, and clear it in a `finally`?
- [ ] Does any new URL reach a launcher or WebView without `UrlSafety`?
- [ ] Does any new `debugPrint` outside `if (kDebugMode)` carry a token, an id,
      or PII?
- [ ] Is a new local role check documented as UX rather than relied on?
- [ ] Does a negative-path test have a positive control, or could it pass
      vacuously? See `cross-repo.instructions.md` section 3.2.
- [ ] Does this change an authorization-relevant default? If so it is not a patch
      release — see `cross-repo.instructions.md` section 4.
- [ ] Have you avoided adding any reference to a private consumer repository, its
      infrastructure, brand, or security findings?
