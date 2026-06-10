# Scripts

This directory contains utility scripts for the fabric_flutter project.

## install-hooks.sh

Installs Git pre-commit hooks that enforce code quality standards.

### Installation

```bash
./scripts/install-hooks.sh
```

### What It Does

The pre-commit hook automatically runs on each `git commit` and performs:

1. **Code Formatting** — Runs `dart format` on all staged Dart files
2. **Static Analysis** — Runs `flutter analyze` to catch potential issues
3. **Print Statement Check** — Fails if `print()` statements are found (use `debugPrint()`)
4. **Documentation Validation** — Warns about double quotes (prefer single quotes)

### Bypassing Hooks

In rare cases where you need to bypass the hooks:

```bash
git commit --no-verify
```

**Note:** This should only be used in emergencies. CI/CD will still enforce all checks on pull requests.

### Uninstalling

To remove the pre-commit hooks:

```bash
rm .git/hooks/pre-commit
```

## Requirements

- Flutter SDK (stable channel, ^3.12.1 or higher)
- Git repository
- Bash shell (Linux/macOS) or Git Bash (Windows)
