---
applyTo: "**"
---

<!--
  REPLICATED FILE — DO NOT EDIT HERE.

  The canonical source of everything below this comment is the FabricElements
  security and agent playbook, authored once and embedded verbatim in each
  FabricElements public package. Fix the canonical copy and re-embed; a local
  edit will be overwritten on the next sync and will silently diverge from the
  other packages in the meantime.

  The body is copied byte for byte. When re-syncing, anchor the copy on content
  -- the top-level title line through the final checklist item -- and never on
  hard-coded line numbers, because a line range that runs long produces a
  perfect match against the wrong boundaries. Choose an anchor string that
  cannot also occur in this comment, or the extraction will match here instead.
  See section 3.2 below.
-->

# Security & Agent Playbook — FabricElements shared packages

**Canonical source.** Authored once and embedded in each FabricElements public package.
If you are an AI agent or a developer working on this package, read this before making changes.

> **This is a PUBLIC repository.** Everything in this file is generic security engineering.
> **Never add references to private consumer repositories, their infrastructure, project
> identifiers, service-account addresses, internal collection names, or their security findings.**
> Downstream consumers may reference this package; this package must never reference them.

---

## 1. You are a library. Your defaults are somebody else's security posture.

A published package does not know who calls it or with what. Assume:

- **Every argument is attacker-controlled.** A consumer will pass a raw request body straight into
  your function, because that is the shortest path and nothing stops them.
- **Your permissive default becomes their vulnerability.** A consumer who never read your source
  inherits whatever you allow.
- **A fix at one call site does not fix the package.** If a consumer patches their own caller, every
  *other* consumer is still exposed. Library-side fixes are the only ones that scale.

### The rule that follows

> **Reset or reject by allow-list, never by denylist.** When you accept a caller object and write it
> somewhere sensitive, enumerate the fields you *permit*; never enumerate the ones you forbid.

A denylist is only correct until someone adds a field. An allow-list fails safe against the next
field nobody thought of.

```ts
// ❌ Resets three known-bad scalars; anything else the caller sent survives.
const user = { ...input, role: 'user', group: undefined, password: undefined };
await db.collection('user').doc(id).set(user, { merge: true });

// ✅ Only named fields can ever reach the write.
const user = pick(input, ['firstName', 'lastName', 'email', 'phone', 'language', 'country']);
await db.collection('user').doc(id).set({ ...user, role: 'user' }, { merge: true });
```

**Why this specific example matters:** a nested authorization *map* (e.g. `groups: {tenant: 'owner'}`)
slips past a reset of the scalar `role` and the scalar `group`. If any consumer's authorization
check reads that map, injecting it during user creation grants privileges in another tenant. Guards
written against scalars do not protect maps.

### Object-spread ordering is a security property

```ts
{ uid: serverValue, ...callerObject }   // ❌ caller can clobber uid
{ ...callerObject, uid: serverValue }   // ✅ server wins
```

When sweeping a codebase for this class, **search the sink, not the source**: the hazard is
positional — *a spread appearing after a literal key inside an object literal*. A pattern anchored
on the variable name (`...data`) cannot match an aliased or nested form (`...opts.metadata`) and
will silently miss real instances.

---

## 2. Security rules for shared code

### 2.1 Validate at the boundary, with a strict schema
Unknown keys must be a **validation failure**, not a silent drop. Silent drops leave the caller
believing their input was honoured and leave you believing it was filtered.

### 2.2 Never trust a caller-settable header, claim or field for identity
If a value can be set by whoever is calling, it identifies nothing. Verify tokens with the
platform's verification API; do not decode-and-trust.

### 2.3 Make external effects replay-safe
At-least-once delivery is the norm: message queues redeliver, webhooks retry, clients double-tap.
Derive a **deterministic id from the provider's event id** and claim it inside a transaction
*before* the side effect.

> 🔴 **Never delete a replay-protection marker on successful consumption.** The marker's
> **existence** is what blocks the replay; a replay succeeds precisely when it finds no marker and
> can create one. Deleting on success makes every token infinitely replayable — and **every replay
> test stays green**, because with the marker gone there is no replay left to detect. Sweep only
> **already-expired** markers, which are safe because expiry is checked before the claim.

### 2.4 Make read-check-write atomic
Serverless runtimes scale horizontally. Any quota, capacity or balance check that reads, decides,
then writes is a race under concurrent invocation. Use a transaction, or an atomic numeric operator.

### 2.5 Validate outbound URLs (SSRF)
If a caller supplies a URL you fetch, block: `127.0.0.0/8`, `10/8`, `172.16/12`, `192.168/16`,
`169.254/16` (including cloud metadata endpoints such as `169.254.169.254`), `::1`, `fc00::/7`,
`fe80::/10`, NAT64 `64:ff9b::/96`, and **IPv4-mapped IPv6** (`::ffff:169.254.169.254` — the most
commonly missed bypass). Resolve DNS, re-check the resolved address, pin the connection to it, and
**re-validate every redirect hop**. Reject non-`http(s)` schemes outright.

### 2.6 Never build a query or path from unvalidated input
Bind parameters; validate identifiers against an anchored pattern before interpolating them into a
table name, document path or storage object path. Derive storage paths server-side from validated
components — never accept a caller-supplied path.

### 2.7 Fail closed, and never leak internals
Missing configuration, an absent secret or an unreachable dependency must **deny**, not fall back to
an unauthenticated path. Return generic errors to callers; log detail internally. Never return a
stack trace.

### 2.8 Know which platform paths bypass declarative rules
Admin/server SDKs bypass client security rules entirely — that is their purpose. Separately,
**cross-service rules** (a storage rule calling into a database) execute as a *service agent* under
IAM and **also bypass** the other service's rules. A deny rule in one service is therefore **not**
defence in depth for a cross-service check in another.

---

## 3. Evidence standards

### 3.1 The citation rule

> **A negative claim needs a citation to the artifact that would have contained the positive.**
> A `file:line`, a test assertion, a live API read, a query result.
> *"I looked and didn't see it"* is not a citation.

At review time it reduces to one question: *what would this have shown if the thing existed, and did
you actually look at that?*

The recurring failure is **inferring absence from an incomplete source** — a grep that structurally
cannot match the pattern you are hunting; an ignore-rule that does not apply to already-tracked
files; a stale local ref; memory of a file instead of the file.

### 3.2 A test can pass and mean nothing

Two distinct failure modes, both of which produce a green suite:

1. **It asserted nothing.** A negative-path test (*"X is rejected"*) passes **vacuously** if a change
   removed the precondition that made X reachable. **Negative-path tests need a positive control**
   proving the path was actually exercised.
2. **It compared the wrong thing, correctly.** Extracting a block by hard-coded line numbers and
   diffing it against the *same* over-long range on both sides matches perfectly while the
   boundaries are wrong. **Anchor extractions on content, not line numbers**, and make the control
   assert the boundary, not merely the presence.

The same caution applies to investigative probes: a probe that denies in **both** the positive and
the negative case has no positive control and is inconclusive, not confirmation.

### 3.3 Prove before/after
Build the pre-fix commit in a throwaway worktree and run the *identical* probe against it. A
measured `ACCEPTED → REJECTED` is evidence; an assertion that a fix works is not.

### 3.4 Record negative results
A refuted finding is a real deliverable. Disproving a suspected vulnerability prevents wasted effort
and wrong fixes. Never quietly drop a claim you disproved — write down what you checked and why it
was clean.

### 3.5 Order staged work so a partial landing is inert, not misleading

When a change lands in stages — or is merged before you have finished — **sequence the stages so
that stopping halfway leaves the repository safe rather than dishonest.**

Code first, then the documentation and CHANGELOG that describe it. If the docs land first, the
package advertises a guarantee it does not yet provide, and a consumer who reads the CHANGELOG will
act on it. That is the failure mode nobody catches later.

Same principle as §2.7: **false confidence is worse than a documented gap.** A documented gap gets
fixed; a false one gets relied upon.

---

## 4. Breaking-change discipline for a published package

Consumers pin you, often by exact commit. A tightening change lands in *their* release cycle, not
yours.

- **Prefer additive, opt-in hardening.** A new strict function beside the old one lets consumers
  migrate deliberately.
- **When a default must change, say so loudly** — a major version, a CHANGELOG entry that names the
  security consequence, and a migration note showing the before/after call site.
- **Never silently change an authorization-relevant default in a patch release.**
- **Consumers may pin an exact SHA.** A fix on `main` is not a fix in production until each consumer
  bumps. Note in the CHANGELOG when a change is security-relevant so consumers can prioritise.

---

## 5. Working as an agent in this repository

- **One session ≈ one branch ≈ one PR.** Scope to a single unit of work.
- **Assign file ownership explicitly** when several sessions edit one repo in parallel, and state
  which paths are off-limits.
- **A shared new module needs a single canonical author.** Two independent implementations of one
  security primitive will drift, and one will be weaker.
- **Push back on instructions that are wrong.** A coordinator's suggestion touching a security
  invariant should be treated as a question about the invariant, not an instruction — the question
  form is self-cancelling when wrong.
- **State-dependent claims carry an implicit timestamp.** A hash, a test count or a merge check must
  be re-measured, not re-quoted.
- **A control can exist, pass its tests, and still be inert.** The code is correct and the tests are
  honest, but an **external precondition owned by someone else** is missing — a caller that never
  supplies the input, a database index that was never created, an operational setting nobody
  applied. For any control you ship, name what must be true *outside this package* for it to
  actually run. Beware best-effort paths that degrade to a warning: their failure is
  indistinguishable from "nothing to do".
- **Before using a record as a discriminator over historical data, ask whether it exists for the
  WHOLE history — not merely whether it is durable.** These are different questions and the first is
  the one that bites. A field introduced by your own recent change is the **highest-risk** case,
  because it looks canonical precisely because it is clean, new and well-structured. Two cheap
  habits beat insight here: ask questions that send you **to the artifact** rather than to reason
  about it, and reason about **consequence-if-wrong** — noticing a tool would be *useless* is often
  easier than noticing it would be *unsafe*, and arrives at the same fix.
- **A green suite can be self-contradictory.** Two individually-passing tests can encode opposite
  models of the same behaviour; no per-test review and no coverage metric reveals it, because
  coverage is complete. Only the test that *composes* them fails. When a comment and the code
  disagree, write the composed test before believing either.
- **A change that removes capability is a REGRESSION, even when the motive is security.** A closed
  grammar, allow-list or schema must be **complete, not minimal** — the risk usually comes from
  accepting *arbitrary input*, not from the *number of legitimate options*. For a published package
  this is sharper still: narrowing an accepted input set is a **breaking change** for consumers,
  whatever the motivation. If a control cannot be built without losing behaviour, that is a
  trade-off to surface explicitly, never a silent default.
- **An automated gate cannot see a functionality regression.** Analyzer, tests and a build can all
  pass on a change that silently removes features. Every automated gate is code-facing. When a
  change **narrows** an interface, add an **inventory test** asserting what must still be there —
  the capability equivalent of a positive control.
- **When a package and its consumers must change together, the PERMISSIVE side ships first.**
  Whichever side *widens* what is accepted must be released and adopted before the side that starts
  depending on it. Widening is backward-compatible; depending on a widening that hasn't shipped is
  not. For a published package this is sharper than in a single service, because you cannot deploy
  your consumers — a version that *requires* a new input is a breaking change the moment it
  publishes, while a version that *accepts* one is safe. So: accept the new input in release N,
  let consumers adopt it, and only require it in a later major.
- **Parameter binding protects values, not identifiers.** A column name, table name, sort field or
  operator cannot be bound — it must come from an allow-list, with the caller sending a *key* that
  is mapped, never a string that reaches the query text. "We bind everything, so we're safe" is a
  plausible claim that becomes false the moment one input names an identifier.
- **Never add co-authorship attribution.** No `Co-authored-by:` trailer on any commit, pull request
  or merge, regardless of tooling defaults. A rebase, amend or squash re-creates commit messages, so
  re-check after one: `git log <base>..HEAD --format='%B' | grep -ci 'co-authored-by'` must print
  `0` — and positive-control the grep, because a zero from an untested probe is not evidence.
  **A clean message check is necessary but NOT sufficient.** GitHub's squash merge generates
  `Co-authored-by:` trailers **server-side, from the authorship of the squashed commits**. A branch
  whose every commit message greps clean still produces a merge commit carrying the trailer if any
  commit's *author* differs from the merging identity, and a local `commit-msg` hook cannot
  intercept it — it never runs. So also assert authorship:
  `git log <base>..HEAD --format='%an|%cn'` must show only expected identities.
- **Public repository hygiene:** never add a reference to a private consumer repository, its
  infrastructure, project identifiers, service accounts, internal data model or security findings.
  Generic security lessons are fine; the identity of who was affected is not.

---

## 6. Before you merge

- [ ] Does any new function accept a caller object and write it somewhere sensitive? Allow-list it.
- [ ] Does any object literal spread caller data **after** a server-authored key?
- [ ] Is every read-check-write on a quota, capacity or balance inside a transaction?
- [ ] Does any new external effect have a deterministic id and a claim-before-effect?
- [ ] Does any new outbound fetch validate the URL, re-check after DNS, and re-validate redirects?
- [ ] Does missing configuration fail **closed**?
- [ ] Do the new tests have positive controls, or could they be passing vacuously?
- [ ] Is this a behaviour change consumers must know about? CHANGELOG + version accordingly.
- [ ] Have you avoided naming any private consumer repository or its infrastructure?
