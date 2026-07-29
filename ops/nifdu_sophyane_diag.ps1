# ==============================================
# C:\nifdu\ops\nifdu_sophyane_diag.ps1
# NIFDU / SOPHYANE â€” DIAGNOSTIC / REALITY CHECK
# ----------------------------------------------
# - Prints a banner (so it's never silent)
# - Shows latest Agent 3 response log (first 80 lines)
# - Lists generated Sophyane frontend files
# - Verifies key files exist
# - Shows docs + DB schema presence
# - Tries to open Sophyane in browser
# ==============================================

$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$m,
        [string]$c = "Gray"
    )
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $c) { $c = "Gray" }
        Write-Host $m -ForegroundColor $c
    } catch {
        Write-Host $m
    }
}

Say "`n=== NIFDU / SOPHYANE DIAG START ===`n" "Yellow"

# ---------------------------
# 1) FIND LATEST AGENT3 LOG
# ---------------------------
$logDir = "C:\sophyane\logs"
if (-not (Test-Path $logDir)) {
    Say "Log directory not found: $logDir" "Red"
} else {
    $latestLog = Get-ChildItem $logDir -Filter "sophyane_agent3_response_*.json" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

    if ($null -eq $latestLog) {
        Say "No sophyane_agent3_response_*.json logs found in $logDir" "Yellow"
    } else {
        Say "`nLatest Agent 3 log:" "Cyan"
        Say "  $($latestLog.FullName)" "Green"

        Say "`nShort preview of Agent 3 response (first ~80 lines):" "Cyan"
        try {
            Get-Content $latestLog.FullName -TotalCount 80 | ForEach-Object {
                Write-Host "  $_"
            }
        } catch {
            Say "  Failed to read log file: $($_.Exception.Message)" "Red"
        }
    }
}

# ---------------------------
# 2) CHECK FRONTEND FILES
# ---------------------------
$rootApp = "C:\webroot\nifdu.com\www\apps\sophyane"
Say "`nChecking Sophyane frontend path: $rootApp" "Cyan"

if (-not (Test-Path $rootApp)) {
    Say "  MISSING: $rootApp (no directory)" "Red"
} else {
    Say "  EXISTS: $rootApp" "Green"

    Say "`nTree (depth <= 2):" "Cyan"
    try {
        Get-ChildItem $rootApp -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName.Substring($rootApp.Length).Split([IO.Path]::DirectorySeparatorChar).Count -le 3
        } | ForEach-Object {
            $rel = $_.FullName.Substring($rootApp.Length)
            if (-not $rel) { $rel = "\" }
            Write-Host ("  {0,-6} {1}" -f ($_.PSIsContainer ? "[DIR]" : "[FILE]"), $rel)
        }
    } catch {
        Say "  Failed to list tree: $($_.Exception.Message)" "Red"
    }

    $filesToCheck = @(
        "index.html",
        "js\app.js",
        "css\styles.css"
    )

    Say "`nKey file existence check:" "Cyan"
    foreach ($f in $filesToCheck) {
        $full = Join-Path $rootApp $f
        if (Test-Path $full) {
            Say ("  OK      {0}" -f $f) "Green"
        } else {
            Say ("  MISSING {0}" -f $f) "Red"
        }
    }
}

# ---------------------------
# 3) CHECK DOCS & DB SCHEMA
# ---------------------------
$docsDir = "C:\sophyane\docs"
$dbSchema = "C:\sophyane\db\schema_sophyane.sql"

Say "`nDocs & DB schema:" "Cyan"

if (Test-Path $docsDir) {
    Say "  Docs dir: $docsDir" "Green"
    try {
        Get-ChildItem $docsDir -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host ("    - {0}" -f $_.Name)
        }
    } catch {
        Say "  Failed to list docs: $($_.Exception.Message)" "Red"
    }
} else {
    Say "  Docs dir missing: $docsDir" "Yellow"
}

if (Test-Path $dbSchema) {
    Say "  DB schema: $dbSchema" "Green"
} else {
    Say "  DB schema missing: $dbSchema" "Yellow"
}

# ---------------------------
# 4) OPTIONAL â€” LAUNCH BROWSER
# ---------------------------
Say "`nAttempting to launch Sophyane in browser..." "Cyan"
$targetUrl = "https://sophyane.com/apps/sophyane"

try {
    $edge = (Get-Command "msedge.exe" -ErrorAction SilentlyContinue)
    if ($edge) {
        Start-Process "msedge.exe" $targetUrl
        Say "  Opened in Edge: $targetUrl" "Green"
    } else {
        $chrome = (Get-Command "chrome.exe" -ErrorAction SilentlyContinue)
        if ($chrome) {
            Start-Process "chrome.exe" $targetUrl
            Say "  Opened in Chrome: $targetUrl" "Green"
        } else {
            Say "  Could not find msedge.exe or chrome.exe in PATH. Open manually:" "Yellow"
            Say "    $targetUrl" "Gray"
        }
    }
} catch {
    Say "  Failed to auto-open browser: $($_.Exception.Message)" "Yellow"
    Say "  Please open manually: $targetUrl" "Gray"
}

Say "`n=== NIFDU / SOPHYANE DIAG END ===`n" "Yellow"
