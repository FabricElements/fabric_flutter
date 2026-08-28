---
applyTo: ".github/workflows/**, pubspec.yaml, CHANGELOG.md"
---

# CI & Deployment Instructions

These rules govern the CI workflow (`.github/workflows/ci.yml`), `pubspec.yaml`, and the release
process for `fabric_flutter`. This is a **Dart/Flutter package** — it is published to
[pub.dev](https://pub.dev/packages/fabric_flutter), not deployed as an application.

---

## 1. CI workflow overview

The single workflow file is `.github/workflows/ci.yml`. It runs on:

- **Push** to `main`.
- **Pull requests** targeting `main` or any `ernysans-**` branch.

### Steps (in order — do not reorder)

| Step | Command | Purpose |
|------|---------|---------|
| Checkout | `actions/checkout@v7` | Clean source snapshot. |
| Setup Flutter | `subosito/flutter-action@v2`, channel `stable`, version `3.44.8`, cache enabled | Pins the exact toolchain so results are reproducible. |
| Install dependencies | `flutter pub get` | Must always run first. |
| Rebuild generated code | `dart run build_runner build --delete-conflicting-outputs` | Regenerates `*.g.dart` before analysis/tests; catches drift between models and generated files. |
| Analyze | `flutter analyze` | Must exit 0; zero issues is the gate. |
| Test | `flutter test` | Full suite; must exit 0. |

**Do not** reorder or skip steps. Analysis before generated-code rebuild will fail on missing
symbols; tests before analysis may mask type errors.

### Updating the pinned Flutter version

1. Change `flutter-version` in `ci.yml`.
2. Update the SDK constraint in `pubspec.yaml` (`environment.flutter`) to match.
3. Update the version reference in `.github/copilot-instructions.md` §1 and §10.
4. Keep all three in sync — a mismatch causes `flutter pub get` to reject the lock file in CI.

---

## 2. `pubspec.yaml` conventions

- **`version`** — the single source of truth. Must match the latest `CHANGELOG.md` release heading
  and the version badge in `README.md`. The three move together; never update one without the others.
- **`environment.sdk`** — Dart SDK constraint (currently `^3.12.2`).
- **`environment.flutter`** — Flutter SDK constraint (currently `>=3.44.8 <4.0.0`).
- **Dependency versions** — keep them in sync with the `Core Dependencies` table in `README.md`.
  When bumping a dependency, update both files and add a `### Dependencies` entry in `CHANGELOG.md`.

### Adding or removing a dependency

1. Edit `pubspec.yaml` (add/remove/change the version constraint).
2. Run `flutter pub get` locally to update `pubspec.lock`.
3. Commit **both** `pubspec.yaml` and `pubspec.lock`.
4. Update the `Core Dependencies` table in `README.md`.
5. Add a `### Dependencies` entry in `CHANGELOG.md`.

**Never hand-edit `pubspec.lock`.**

---

## 3. Release process (pub.dev publish)

`fabric_flutter` is published to pub.dev. Follow these steps when preparing a release:

### Pre-release checklist

- [ ] All features and fixes for the release are merged to `main`.
- [ ] `flutter analyze` reports zero issues.
- [ ] `flutter test` passes in full.
- [ ] `dart run build_runner build --delete-conflicting-outputs` produces no diff in `*.g.dart` files.
- [ ] `CHANGELOG.md` has an `## [Unreleased]` section with all user-facing changes categorized under
      `### Added`, `### Changed`, `### Fixed`, and/or `### Dependencies`.
- [ ] `README.md` reflects the new API surface (Architectural Map, Core Dependencies table, code
      samples all compile against the release version).

### Bump the version

1. Edit `version` in `pubspec.yaml` following [semver](https://semver.org):
   - **Patch** (`x.y.Z`): bug fixes only, no API changes.
   - **Minor** (`x.Y.0`): new backward-compatible features.
   - **Major** (`X.0.0`): breaking changes — see §4.
2. Rename the `## [Unreleased]` heading in `CHANGELOG.md` to `## [x.y.z] - YYYY-MM-DD`.
3. Update the version badge/line in `README.md`.
4. Commit with message `chore: bump version to x.y.z`.

### Dry-run before publishing

```bash
dart pub publish --dry-run
```

Fix any warnings before proceeding. Common issues:

- Forgotten `*.g.dart` (regenerate with `build_runner`).
- Analysis warnings in files not excluded by `analysis_options.yaml`.
- Missing `LICENSE` or `README.md` (do not remove these files).

### Publish

```bash
dart pub publish
```

This requires pub.dev credentials. Publishing is done by a maintainer with the appropriate pub.dev
publisher access.

---

## 4. Breaking-change discipline

A change is breaking if it removes or renames a public API, tightens a parameter type, or changes
observable behavior a consumer was relying on. Breaking changes:

- **Require a major version bump** — never in a patch release.
- **Must be documented** in `CHANGELOG.md` under `### Changed` or `### Removed`, with a migration
  note showing the before/after call site.
- **Must not silently change an authorization-relevant default** — this is a security property,
  not just a semver property (see `.github/instructions/security.instructions.md` §4).

When a breaking change is unavoidable, prefer the additive path first: add the new behavior
alongside the old, deprecate the old with `@Deprecated('Use X instead. Will be removed in vN.')`,
and remove in the next major.

---

## 5. What NOT to commit to this repository

The following must never be committed, regardless of the release stage:

- `google-services.json` or `GoogleService-Info.plist` — Firebase config belongs in the consuming
  app, never in this package.
- Service-account JSON, private keys, or signing material of any kind.
- App Check attestation debug tokens.
- Any bearer or session token captured from a real device or environment.
- Platform directories (`ios/`, `android/`, `web/`, `macos/`, `windows/`, `linux/`) — this
  package has no platform code and those directories must not be created here.

If CI needs secrets (for future integrations), they must be stored as GitHub Actions secrets and
injected via `${{ secrets.NAME }}`, never hardcoded.

---

## 6. Workflow file hygiene

- **Pin action versions** by a major tag (`@v7`, `@v2`). Do not use `@main` or `@latest`.
- **`permissions`** — keep the `contents: read` / `id-token: write` grant minimal; do not widen it.
- Add steps only when they are verifiably necessary. Each added step increases CI time for every
  contributor.
- If a new workflow file is needed (e.g. `publish.yml`), keep its steps consistent with `ci.yml`
  (same Flutter version pin, same `build_runner` command, same `dart format` expectations).

**DO NOT**

- ❌ Use the deprecated `flutter pub run build_runner` — use `dart run build_runner` instead.
- ❌ Skip `flutter pub get` or run steps before it.
- ❌ Change the pinned Flutter version without updating `pubspec.yaml` and the instruction files.
- ❌ Publish to pub.dev before `flutter analyze` and `flutter test` pass on `main`.
- ❌ Merge a PR that bumps the version without a corresponding `CHANGELOG.md` entry.
- ❌ Commit platform directories or Firebase credential files to this repository.
