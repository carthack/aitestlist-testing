#!/bin/bash
# aitestlist-testing plugin installer for Linux/macOS
# Usage: curl -sSL https://raw.githubusercontent.com/carthack/aitestlist-testing/main/install.sh | bash

set -e

PLUGIN_NAME="aitestlist-testing"
REPO_URL="https://github.com/carthack/aitestlist-testing.git"
VERSION="1.0.0"
PLUGIN_DIR="$HOME/.claude/plugins/cache/aitestlist/$PLUGIN_NAME/$VERSION"
INSTALLED_FILE="$HOME/.claude/plugins/installed_plugins.json"

echo "=== AI TestList Testing Plugin Installer ==="
echo ""

# Check git
if ! command -v git &> /dev/null; then
    echo "Error: git is required. Install it first."
    exit 1
fi

# Remove old installation if exists
if [ -d "$PLUGIN_DIR" ]; then
    echo "Removing previous installation..."
    rm -rf "$PLUGIN_DIR"
fi

# Clone
echo "Installing $PLUGIN_NAME v$VERSION..."
mkdir -p "$(dirname "$PLUGIN_DIR")"
git clone --depth 1 "$REPO_URL" "$PLUGIN_DIR" 2>/dev/null
rm -rf "$PLUGIN_DIR/.git"

# Register in installed_plugins.json
mkdir -p "$(dirname "$INSTALLED_FILE")"
if [ ! -f "$INSTALLED_FILE" ]; then
    echo '[]' > "$INSTALLED_FILE"
fi

# Check if already registered
if grep -q "\"$PLUGIN_NAME\"" "$INSTALLED_FILE" 2>/dev/null; then
    echo "Plugin already registered."
else
    # Add entry (simple append without jq dependency)
    python3 -c "
import json, sys
path = '$INSTALLED_FILE'
with open(path) as f:
    plugins = json.load(f)
plugins.append({
    'name': '$PLUGIN_NAME',
    'version': '$VERSION',
    'path': '$PLUGIN_DIR',
    'source': 'github'
})
with open(path, 'w') as f:
    json.dump(plugins, f, indent=2)
print('Plugin registered.')
" 2>/dev/null || echo "Note: Could not auto-register. Add manually to $INSTALLED_FILE"
fi

# Clean up old standalone files
echo ""
echo "Cleaning up old standalone files..."
OLD_FILES=(
    "$HOME/.claude/agents/test-creator.md"
    "$HOME/.claude/agents/test-exec.md"
    "$HOME/.claude/skills/checklist-test-creator"
    "$HOME/.claude/skills/exec-test"
    "$HOME/.claude/skills/aitestlist-error-report"
)
for f in "${OLD_FILES[@]}"; do
    if [ -e "$f" ]; then
        rm -rf "$f"
        echo "  Removed: $f"
    fi
done

echo ""
echo "=== Installation complete ==="
echo "Plugin: $PLUGIN_NAME v$VERSION"
echo "Location: $PLUGIN_DIR"
echo ""
echo "Available commands:"
echo "  /aitestlist-testing:create  - Create QA tests"
echo "  /aitestlist-testing:exec    - Execute test queue"
echo "  /aitestlist-testing:report  - Generate error report"
echo "  /aitestlist-testing:status  - Check connection status"
