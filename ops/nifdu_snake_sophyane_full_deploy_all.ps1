param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Say {
    param([string]$m, [string]$c = "Gray")
    try {
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$Project = "snake_sophyane_full"
$AppRoot = "C:\nifdu\src\apps\snake_sophyane_full\web"

# NIFDU main site (what router is actually using)
$MainRoot      = "C:\webroot\nifdu.com\www"
$MainAppsRoot  = Join-Path $MainRoot "apps"
$MainTargetDir = Join-Path $MainAppsRoot $Project

# Sophyane mirror (for future host-based routing)
$SophyRoot      = "C:\webroot\sophyane.com\www"
$SophyAppsRoot  = Join-Path $SophyRoot "apps"
$SophyTargetDir = Join-Path $SophyAppsRoot $Project

Say ""
Say "=== NIFDU SNAKE DEPLOY (snake_sophyane_full) — MAIN + SOPHYANE MIRROR ==="
Say ""

New-Item -ItemType Directory -Path $AppRoot       -Force | Out-Null
New-Item -ItemType Directory -Path $MainAppsRoot  -Force | Out-Null
New-Item -ItemType Directory -Path $MainTargetDir -Force | Out-Null
New-Item -ItemType Directory -Path $SophyAppsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $SophyTargetDir -Force | Out-Null

# 1) Pick source dir
if (Test-Path (Join-Path $AppRoot "dist")) {
    $SourceDir = Join-Path $AppRoot "dist"
} elseif (Test-Path (Join-Path $AppRoot "build")) {
    $SourceDir = Join-Path $AppRoot "build"
} else {
    $SourceDir = $AppRoot
}

Say ("[INFO] Using source dir: {0}" -f $SourceDir) "Gray"

function Copy-ToTarget {
    param(
        [string]$TargetDir,
        [string]$Label
    )
    Say ("[STEP] Copying assets to {0}: {1}" -f $Label, $TargetDir) "Cyan"

    Get-ChildItem -Path $TargetDir -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path $SourceDir) {
        Copy-Item -Path (Join-Path $SourceDir "*") -Destination $TargetDir -Recurse -Force
    } else {
        Say ("[WARN] Source dir {0} does not exist; leaving {1} empty." -f $SourceDir, $TargetDir) "DarkYellow"
    }
}

# Copy to main + mirror
Copy-ToTarget -TargetDir $MainTargetDir  -Label "nifdu.com"
Copy-ToTarget -TargetDir $SophyTargetDir -Label "sophyane.com"

Say ""
Say "[OK] Snake deploy complete." "Green"
Say ""
