---
applyTo: "README.md,CHANGELOG.md"
---

# README & Changelog Maintenance Instructions

`README.md` is the canonical onboarding document for this package and must stay synchronized with the codebase.

- When directories or significant files in `lib/` are added, removed, or renamed, update the **Architectural Map** tree in the README to match.
- When dependencies in `pubspec.yaml` change, update the **Core Dependencies** table.
- When the package version changes, update the **Version** line at the top of the README, the `version` field in `pubspec.yaml`, and add a corresponding `CHANGELOG.md` entry (newest first, matching the existing entry format).
- Document new components, state classes, helpers, or workflows in the appropriate sections (**Core Workflows & Logic**, **Codebase Best Practices**, **Context Map for AI Tools**) using the established formatting: Markdown tables for matrices, fenced ` ```dart ` blocks for samples, and `---` separators between major sections.
- Keep all README code samples compilable against the current public API; update them whenever public APIs change.
- Keep instructions in the README consistent with `.github/copilot-instructions.md`; if conventions change, update both.
