# Phase 2 Validation Guide

This document outlines the validation steps required to complete the Phase 2 codebase compliance sweep.

## Prerequisites

Ensure you have Flutter SDK installed (stable channel, compatible with SDK `^3.12.1`):
```bash
flutter --version
```

## Validation Steps

### 1. Regenerate Serialized Models

Run the build_runner to regenerate all `.g.dart` files after the serialization fixes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Or using the npm script:
```bash
npm run serialize
```

**Expected Result:** All `.g.dart` files should regenerate without errors.

### 2. Run Dart Format

Apply consistent formatting across the codebase:

```bash
dart format .
```

**Expected Result:** All files should be formatted successfully with no parsing errors.

### 3. Run Flutter Analyze

Check for linting and analysis issues:

```bash
flutter analyze
```

**Expected Result:** No issues reported. The analyzer should return with exit code 0.

### 4. Run Flutter Test Suite

Execute the complete test suite:

```bash
flutter test
```

**Expected Result:** All tests must pass.

## Known Issues to Verify

### State Files Trailing Commas

The audit report identified 8 state files with potential trailing comma issues:
- `lib/state/state_api.dart`
- `lib/state/state_collection.dart`
- `lib/state/state_document.dart`
- `lib/state/state_global.dart`
- `lib/state/state_notifications.dart`
- `lib/state/state_shared.dart`
- `lib/state/state_user.dart`
- `lib/state/state_users.dart`

**Action:** After running `dart format .`, verify these files format correctly. Manual inspection showed these files already have proper formatting, but the formatter will apply any needed changes.

### Generated Files

The following generated files use null-aware element syntax (`?`):
- `lib/component/pagination_container.dart` (lines 311, 313, 327, 329)
- `lib/serialized/chart_wrapper.g.dart` (multiple lines)
- `lib/serialized/logs_data.g.dart` (line 19)

**Action:** These files use valid Dart 3 syntax. If the formatter reports issues, ensure you're using a Dart SDK version that supports null-aware elements (Dart 3.0+).

## Troubleshooting

### If `dart format` reports parsing errors:

1. Check your Dart SDK version: `dart --version`
2. Ensure it's Dart 3.0 or later
3. Try `flutter pub get` to ensure dependencies are resolved
4. If issues persist with `.g.dart` files, regenerate them first with build_runner

### If `flutter analyze` reports issues:

1. Review the specific issues reported
2. Most should be resolved by the Phase 1 and Phase 2 work
3. If new issues appear, they may be from the documentation changes - review and fix

### If tests fail:

1. Check if the failures are pre-existing (compare with main branch)
2. Ensure no functional logic was changed during documentation
3. Review test output for specific failures

## Final Checklist

- [ ] `dart run build_runner build --delete-conflicting-outputs` completes successfully
- [ ] `dart format .` completes without parsing errors
- [ ] `flutter analyze` reports no issues
- [ ] `flutter test` all tests pass
- [ ] Review git diff to ensure no breaking changes
- [ ] Update CHANGELOG.md if needed

## Success Criteria

All validation steps must pass cleanly before merging the Phase 2 compliance work. The codebase should be at 100% compliance with:

1. **Effective Dart Documentation** standards on all public/private API elements
2. **Code Style** rules (single quotes, no print(), trailing commas, debugPrint)
3. **Serialization Patterns** (nullable fromJson, null coalescing, explicitToJson)

## Next Steps After Validation

1. Update CHANGELOG.md with compliance improvements
2. Create final compliance report
3. Merge PR
4. Tag release if applicable
