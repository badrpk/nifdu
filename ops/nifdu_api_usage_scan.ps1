# ==============================================
# C:\nifdu\ops\nifdu_api_usage_scan.ps1
# NIFDU API USAGE SCANNER (FRONTEND CODE)
# ----------------------------------------------
# Scans C:\nifdu\src\apps for strings like "/api/"
# and prints a coverage list.
# ==============================================

$ErrorActionPreference = "Stop"

function Say {
    param([string]$m,[string]$c="Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $c) { $c = "Gray" }
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$AppsRoot = "C:\nifdu\src\apps"
if (!(Test-Path $AppsRoot)) {
    Say "[FATAL] Apps root not found: $AppsRoot" "Red"
    exit 1
}

Say "`n=== NIFDU API USAGE SCAN (FRONTEND) ===`n" "Cyan"
Say ("Scanning: {0}" -f $AppsRoot) "Gray"

# Collect all JS/TS/TSX/JSX files (React code)
$codeFiles = Get-ChildItem -Path $AppsRoot -Recurse -Include *.js,*.jsx,*.ts,*.tsx -File

if (-not $codeFiles) {
    Say "[WARN] No React code files found to scan." "DarkYellow"
    exit 0
}

$apiPattern = [regex]"/api/[A-Za-z0-9_\-/]+"
$usage = @{}

foreach ($file in $codeFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $matches = $apiPattern.Matches($text)
    if ($matches.Count -gt 0) {
        $relPath = $file.FullName.Substring($AppsRoot.Length).TrimStart('\')
        foreach ($m in $matches) {
            $api = $m.Value
            if (-not $usage.ContainsKey($api)) {
                $usage[$api] = New-Object System.Collections.Generic.List[string]
            }
            if (-not $usage[$api].Contains($relPath)) {
                $usage[$api].Add($relPath)
            }
        }
    }
}

if ($usage.Count -eq 0) {
    Say "`n[WARN] No /api/... usages found in frontend code." "DarkYellow"
    exit 0
}

Say "`n=== ✅ API USAGE MAP (FROM FRONTEND CODE) ===" "Green"

$usage.Keys | Sort-Object | ForEach-Object {
    $api = $_
    $files = $usage[$api]
    Say "`nAPI: $api" "Yellow"
    foreach ($f in $files) {
        Say "  -> $f" "Gray"
    }
}

Say "`n=== SCAN COMPLETE ===`n" "Cyan"
