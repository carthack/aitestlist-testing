# aitestlist-testing plugin installer for Windows
# Usage: irm https://raw.githubusercontent.com/carthack/aitestlist-testing/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$PluginName = "aitestlist-testing"
$RepoUrl = "https://github.com/carthack/aitestlist-testing.git"
$Version = "1.0.0"
$PluginDir = "$env:USERPROFILE\.claude\plugins\cache\aitestlist\$PluginName\$Version"
$InstalledFile = "$env:USERPROFILE\.claude\plugins\installed_plugins.json"

Write-Host "=== AI TestList Testing Plugin Installer ===" -ForegroundColor Cyan
Write-Host ""

# Check git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: git is required. Install it first." -ForegroundColor Red
    exit 1
}

# Remove old installation if exists
if (Test-Path $PluginDir) {
    Write-Host "Removing previous installation..."
    Remove-Item -Recurse -Force $PluginDir
}

# Clone
Write-Host "Installing $PluginName v$Version..."
$ParentDir = Split-Path $PluginDir -Parent
New-Item -ItemType Directory -Force -Path $ParentDir | Out-Null
git clone --depth 1 $RepoUrl $PluginDir 2>$null
Remove-Item -Recurse -Force "$PluginDir\.git" -ErrorAction SilentlyContinue

# Register in installed_plugins.json
$PluginsDir = Split-Path $InstalledFile -Parent
if (-not (Test-Path $PluginsDir)) {
    New-Item -ItemType Directory -Force -Path $PluginsDir | Out-Null
}
if (-not (Test-Path $InstalledFile)) {
    "[]" | Set-Content $InstalledFile
}

$plugins = Get-Content $InstalledFile | ConvertFrom-Json
$existing = $plugins | Where-Object { $_.name -eq $PluginName }
if (-not $existing) {
    $entry = @{
        name = $PluginName
        version = $Version
        path = $PluginDir
        source = "github"
    }
    $plugins += $entry
    $plugins | ConvertTo-Json -Depth 10 | Set-Content $InstalledFile
    Write-Host "Plugin registered."
} else {
    Write-Host "Plugin already registered."
}

# Clean up old standalone files
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
Write-Host "Plugin: $PluginName v$Version"
Write-Host "Location: $PluginDir"
Write-Host ""
Write-Host "Available commands:"
Write-Host "  /aitestlist-testing:create  - Create QA tests"
Write-Host "  /aitestlist-testing:exec    - Execute test queue"
Write-Host "  /aitestlist-testing:report  - Generate error report"
Write-Host "  /aitestlist-testing:status  - Check connection status"
