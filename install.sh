#!/bin/bash
# aitestlist-testing plugin installer for Linux/macOS
# Usage: curl -sSL https://raw.githubusercontent.com/carthack/aitestlist-testing/main/install.sh | bash

set -e

MARKETPLACE_REPO="carthack/aitestlist-testing"
PLUGIN_NAME="aitestlist-testing"
KNOWN_MARKETPLACES="$HOME/.claude/plugins/known_marketplaces.json"

echo "=== AI TestList Testing Plugin Installer ==="
echo ""

# Check claude CLI
if ! command -v claude &> /dev/null; then
    echo "Error: Claude Code CLI is required."
    echo "Install it from: https://claude.ai/download"
    exit 1
fi

# Step 1: Add marketplace
echo "Adding marketplace..."
claude plugin marketplace add "$MARKETPLACE_REPO" 2>/dev/null || true

# Step 2: Install plugin
echo "Installing plugin..."
claude plugin install "$PLUGIN_NAME" 2>/dev/null || true

# Step 3: Enable auto-update in known_marketplaces.json
if [ -f "$KNOWN_MARKETPLACES" ]; then
    echo "Enabling auto-update..."
    python3 -c "
import json
path = '$KNOWN_MARKETPLACES'
with open(path) as f:
    data = json.load(f)
if 'aitestlist' in data:
    data['aitestlist']['autoUpdate'] = True
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print('Auto-update enabled.')
else:
    print('Warning: aitestlist marketplace not found in known_marketplaces.json')
" 2>/dev/null || echo "Note: Could not enable auto-update. Enable manually via /plugin > Marketplaces."
fi

# Step 4: Clean up old standalone files (pre-plugin era)
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
echo "Auto-update: enabled (new versions install automatically)"
echo ""
echo "Restart Claude Code to activate the plugin."
echo ""
echo "Available skills:"
echo "  @test-creator   - Create QA tests"
echo "  @test-executor  - Execute test queue"
echo "  @test-reporter  - Generate error report"
