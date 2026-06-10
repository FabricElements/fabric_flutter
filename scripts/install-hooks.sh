#!/bin/bash
# Pre-commit hooks installation script for fabric_flutter
# This script installs git hooks that enforce code quality standards

set -e

HOOKS_DIR=".git/hooks"
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

echo "Installing pre-commit hooks for fabric_flutter..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed or not in PATH"
    echo "Please install Flutter SDK first: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository"
    echo "Please run this script from the repository root"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash
# fabric_flutter pre-commit hook
# Enforces code quality standards before each commit

set -e

echo "Running pre-commit checks..."

# Get list of staged Dart files
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.dart$' || true)

if [ -z "$STAGED_DART_FILES" ]; then
    echo "✅ No Dart files staged, skipping checks"
    exit 0
fi

echo "📝 Checking ${STAGED_DART_FILES}" | wc -l | xargs echo "files"

# 1. Run dart format on staged files
echo "1️⃣  Running dart format..."
echo "$STAGED_DART_FILES" | xargs dart format

# Re-stage formatted files
echo "$STAGED_DART_FILES" | xargs git add

# 2. Run flutter analyze
echo "2️⃣  Running flutter analyze..."
if ! flutter analyze --no-pub; then
    echo "❌ Flutter analyze found issues"
    echo "Please fix the issues and try again"
    exit 1
fi

# 3. Check for print() statements (should use debugPrint())
echo "3️⃣  Checking for print() statements..."
PRINT_VIOLATIONS=$(echo "$STAGED_DART_FILES" | xargs grep -n "^\s*print(" || true)
if [ -n "$PRINT_VIOLATIONS" ]; then
    echo "❌ Found print() statements. Please use debugPrint() instead:"
    echo "$PRINT_VIOLATIONS"
    exit 1
fi

# 4. Check for basic documentation issues
echo "4️⃣  Checking documentation patterns..."
# Check for double quotes in staged files (should use single quotes)
QUOTE_VIOLATIONS=$(echo "$STAGED_DART_FILES" | xargs grep -n '".*"' | grep -v "test/" | grep -v ".g.dart" | head -5 || true)
if [ -n "$QUOTE_VIOLATIONS" ]; then
    echo "⚠️  Warning: Found double quotes (prefer single quotes):"
    echo "$QUOTE_VIOLATIONS"
    echo "   (This is a warning, not blocking commit)"
fi

echo "✅ All pre-commit checks passed!"
exit 0
EOF

# Make the hook executable
chmod +x "$PRE_COMMIT_HOOK"

echo "✅ Pre-commit hooks installed successfully!"
echo ""
echo "The following checks will run on each commit:"
echo "  1. dart format (auto-formats staged Dart files)"
echo "  2. flutter analyze (must pass)"
echo "  3. Check for print() statements (must use debugPrint())"
echo "  4. Documentation pattern checks (warnings only)"
echo ""
echo "To bypass hooks in an emergency, use: git commit --no-verify"
echo ""
