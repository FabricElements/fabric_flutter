---
applyTo: "README.md,CHANGELOG.md"
---

# README & Changelog Maintenance Instructions

`README.md` is the canonical onboarding document and `CHANGELOG.md` is the canonical history. Both must stay synchronized with the code and with `.github/copilot-instructions.md`.

## When to update the README

Update `README.md` whenever any of the following change:

- **Directory/file structure** in `lib/` (added, removed, renamed) → update the **Architectural Map** tree to match exactly.
- **Dependencies** in `pubspec.yaml` (added, removed, upgraded) → update the **Core Dependencies** table (the authoritative, versioned list). Keep versions identical to `pubspec.yaml`.
- **Public API** of a documented component, helper, state class, or workflow → update the relevant section (**Architecture Layers & Responsibilities**, **Testing…**, **AI-Assisted Engineering Rules**) and keep code samples compilable against the current API.
- **Package version** (`pubspec.yaml`) → update the **Version** line and the CI badge context at the top of the README.

## When to update the CHANGELOG

- Add an entry for every user-facing or behavioral change, newest first, under an `## [Unreleased]` heading; on release, rename it to `## [x.y.z] - YYYY-MM-DD`.
- Group changes with the existing headings (`### Added`, `### Changed`, `### Fixed`, `### Dependencies`, or descriptive theme headings already in use) and reference issues like `(issue #123)`.
- Version bump = update **all three** together: `version` in `pubspec.yaml`, the **Version** line in `README.md`, and a matching `CHANGELOG.md` entry. Never let them drift.

## How to document a new feature

When a new domain feature/entity is introduced, document its files in the README's map and, if consumer-facing, add a short usage sample. Keep the file-synchronization checklist from `.github/copilot-instructions.md` §11 in mind: `serialized/` model + `.g.dart`, `state/` container (registered in `InitApp` if app-wide), `helper/`, `component/` UI, mirrored `test/`, README, and CHANGELOG.

## Formatting conventions (match existing style)

- Markdown tables for dependency/matrix data.
- Fenced ` ```dart ` blocks for code samples and ` ```bash ` for commands.
- `---` separators between major sections; `> [!IMPORTANT]` callouts for hard rules.

**DO NOT**

- ❌ Change the README version without also updating `pubspec.yaml` and `CHANGELOG.md`.
- ❌ List a dependency version in the README that differs from `pubspec.yaml`.
- ❌ Add README code samples that would not compile against the current public API.
- ❌ Introduce conventions in the README that contradict `.github/copilot-instructions.md` — update both together.
- ❌ Document features that do not exist yet, or leave the Architectural Map out of date after moving files.
