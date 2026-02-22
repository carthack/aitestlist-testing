# aitestlist-testing plugin installer for Windows
# Usage: irm https://raw.githubusercontent.com/carthack/aitestlist-testing/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$MarketplaceRepo = "carthack/aitestlist-testing"
$PluginName = "aitestlist-testing"
$KnownMarketplaces = "$env:USERPROFILE\.claude\plugins\known_marketplaces.json"

Write-Host "=== AI TestList Testing Plugin Installer ===" -ForegroundColor Cyan
Write-Host ""

# Check claude CLI
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Claude Code CLI is required." -ForegroundColor Red
    Write-Host "Install it from: https://claude.ai/download"
    exit 1
}

# Step 1: Add marketplace
Write-Host "Adding marketplace..."
try { claude plugin marketplace add $MarketplaceRepo 2>$null } catch {}

# Step 2: Install plugin
Write-Host "Installing plugin..."
try { claude plugin install $PluginName 2>$null } catch {}

# Step 3: Enable auto-update in known_marketplaces.json
if (Test-Path $KnownMarketplaces) {
    Write-Host "Enabling auto-update..."
    try {
        $data = Get-Content $KnownMarketplaces -Raw | ConvertFrom-Json
        if ($data.aitestlist) {
            $data.aitestlist | Add-Member -NotePropertyName "autoUpdate" -NotePropertyValue $true -Force
            $data | ConvertTo-Json -Depth 10 | Set-Content $KnownMarketplaces -Encoding UTF8
            Write-Host "Auto-update enabled."
        } else {
            Write-Host "Warning: aitestlist marketplace not found in known_marketplaces.json" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Note: Could not enable auto-update. Enable manually via /plugin > Marketplaces." -ForegroundColor Yellow
    }
}

# Step 4: Clean up old standalone files (pre-plugin era)
Write-Host ""
Write-Host "Cleaning up old standalone files..."
$OldFiles = @(
    "$env:USERPROFILE\.claude\agents\test-creator.md",
    "$env:USERPROFILE\.claude\agents\test-exec.md",
    "$env:USERPROFILE\.claude\skills\checklist-test-creator",
    "$env:USERPROFILE\.claude\skills\exec-test",
    "$env:USERPROFILE\.claude\skills\aitestlist-error-report"
)
foreach ($f in $OldFiles) {
    if (Test-Path $f) {
        Remove-Item -Recurse -Force $f
        Write-Host "  Removed: $f"
    }
}

Write-Host ""
Write-Host "=== Installation complete ===" -ForegroundColor Green
Write-Host "Auto-update: enabled (new versions install automatically)"
Write-Host ""
Write-Host "Restart Claude Code to activate the plugin."
Write-Host ""
Write-Host "Available skills:"
Write-Host "  @test-creator   - Create QA tests"
Write-Host "  @test-executor  - Execute test queue"
Write-Host "  @test-reporter  - Generate error report"
