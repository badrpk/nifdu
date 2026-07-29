# ==============================================
# C:\nifdu\ops\nifdu_api_full_report.ps1
# NIFDU API FULL REPORT (DISCOVERY + USAGE MAP)
# ----------------------------------------------
# - Checks NIFDU health
# - Optionally runs Agent 3 API Labs (if script exists)
# - Scans C:\nifdu\src\apps for /api/... usages
# - Compares against canonical API list
# - Prints USED / UNUSED report
# - Saves JSON snapshot in C:\nifdu\build\_diag
# ==============================================

param(
    [string]$BaseUrl     = "http://127.0.0.1",
    [object]$RunLabsFirst = $true,   # accept anything; we coerce later
    [switch]$SkipLabs                 # easy way to skip labs
)

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

$Stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$DiagDir = "C:\nifdu\build\_diag"
New-Item -ItemType Directory -Path $DiagDir -Force | Out-Null

Say "`n=== NIFDU API FULL REPORT (DISCOVERY + USAGE) ===`n" "Yellow"
Say ("BaseUrl : {0}" -f $BaseUrl) "Gray"

# -------------------------------------------------
# Decide whether to run Labs
# -------------------------------------------------
$doLabs = $true

if ($SkipLabs.IsPresent) {
    $doLabs = $false
} else {
    switch ($RunLabsFirst.GetType().FullName) {
        'System.Boolean' {
            $doLabs = [bool]$RunLabsFirst
        }
        'System.String' {
            if ($RunLabsFirst -match '^(false|0)$') {
                $doLabs = $false
            } else {
                $doLabs = $true
            }
        }
        default {
            try {
                $doLabs = [bool]$RunLabsFirst
            } catch {
                $doLabs = $true
            }
        }
    }
}

# -------------------------------------------------
# 1) Check NIFDU /health
# -------------------------------------------------
try {
    $health = Invoke-WebRequest -Uri "$BaseUrl/health" -TimeoutSec 4 -ErrorAction Stop
    Say "[OK] NIFDU is alive at /health" "Green"
} catch {
    Say "[FATAL] NIFDU is not responding at $BaseUrl/health" "Red"
    Say "       Start nifdu.exe and re-run this report." "Red"
    exit 1
}

# -------------------------------------------------
# 2) Optionally run Agent 3 API Labs (if script exists)
# -------------------------------------------------
$LabsScript = "C:\nifdu\ops\nifdu_agent3_use_all_apis.ps1"
if ($doLabs -and (Test-Path $LabsScript)) {
    Say "`n--- STEP 2: Running Agent 3 API Labs (to ensure fresh apps) ---" "Cyan"
    try {
        powershell -ExecutionPolicy Bypass `
            -File $LabsScript `
            -BaseUrl $BaseUrl `
            -MaxCyclesPerLab 3
        Say "[OK] API Labs run completed." "Green"
    } catch {
        Say "[WARN] Labs script threw an error, continuing with scan anyway." "DarkYellow"
    }
} else {
    Say "`n[INFO] Skipping Labs run (by flag or script missing)." "DarkYellow"
}

# -------------------------------------------------
# 3) Frontend scan: find /api/... usages in React code
#    (also tracks /health)
# -------------------------------------------------
function Get-FrontendApiUsage {
    param(
        [string]$AppsRoot = "C:\nifdu\src\apps"
    )

    if (!(Test-Path $AppsRoot)) {
        Say "[FATAL] Apps root not found: $AppsRoot" "Red"
        return $null
    }

    Say "`n--- STEP 3: Scanning frontend apps for /api/... ---" "Cyan"
    Say ("Apps root: {0}" -f $AppsRoot) "Gray"

    $codeFiles = Get-ChildItem -Path $AppsRoot -Recurse -Include *.js,*.jsx,*.ts,*.tsx -File |
                 Where-Object {
                     $_.FullName -notmatch '\\node_modules\\' -and
                     $_.FullName -notmatch '\\dist\\'         -and
                     $_.FullName -notmatch '\\\.vite\\'
                 }

    if (-not $codeFiles) {
        Say "[WARN] No React/TS code files found to scan." "DarkYellow"
        return @{}
    }

    # Catch both /api/... and /health
    $apiPattern = [regex]"(/api/[A-Za-z0-9_\-/]+|/health\b)"
    $usage = @{}

    foreach ($file in $codeFiles) {
        $text = $null
        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            if ($null -eq $raw) { continue }
            $text = '' + $raw
        } catch {
            continue
        }

        if ($null -eq $text -or [string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        $matches = $null
        try {
            $safeText = '' + $text
            if ($null -eq $safeText) { continue }
            $matches = $apiPattern.Matches($safeText)
        } catch {
            continue
        }

        if ($matches -and $matches.Count -gt 0) {
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

    return $usage
}

$usageMap = Get-FrontendApiUsage
if ($null -eq $usageMap) {
    Say "[FATAL] Usage scan failed." "Red"
    exit 1
}

# -------------------------------------------------
# 4) Canonical API list (what NIFDU should expose)
# -------------------------------------------------
$CanonicalApis = @(
    # Core / health
    "/health",
    "/api/health",
    "/api/ping",
    "/api/db_health",
    "/api/list",
    "/api/log",

    # AI / chat / codegen / vibe
    "/api/chat",
    "/api/ai/complete",
    "/api/ai/embed",
    "/api/ai/models",
    "/api/ai/config",
    "/api/ai/recall",
    "/api/codegen",
    "/api/vibe",
    "/api/behavior_test",

    # Truth / compile / run
    "/api/truth",
    "/api/compile",
    "/api/run",

    # AV
    "/api/av",
    "/api/av/plan",
    "/api/av/sprite",
    "/api/av/render",
    "/api/av/control",

    # RAG / RL / Train
    "/api/rag",
    "/api/rl",
    "/api/train",

    # Retail / business / ops
    "/api/retail",
    "/api/retail/blueprints",
    "/api/lead",
    "/api/project",
    "/api/projects/accept",
    "/api/auth/generate_key",

    # Proxy / deploy
    "/api/proxy/config",
    "/api/proxy/routes",
    "/api/proxy/services",
    "/api/proxy/reload",
    "/api/deploy",

    # Misc
    "/api/ws/prices"
) | Sort-Object -Unique

# -------------------------------------------------
# 5) Build report: USED vs UNUSED
# -------------------------------------------------
Say "`n--- STEP 4: Building USED / UNUSED map ---" "Cyan"

$report      = @()
$usedCount   = 0
$unusedCount = 0

foreach ($api in $CanonicalApis) {
    if ($usageMap.ContainsKey($api)) {
        $status = "USED"
        $usedCount++
        $files  = $usageMap[$api]
    } else {
        $status = "UNUSED"
        $unusedCount++
        $files  = @()
    }

    $report += [PSCustomObject]@{
        Api    = $api
        Status = $status
        Files  = ($files -join "; ")
    }
}

# -------------------------------------------------
# 6) Print nice console summary
# -------------------------------------------------
Say "`n=== ✅ NIFDU API USAGE REPORT ===" "Green"
Say ("Total canonical APIs : {0}" -f $CanonicalApis.Count) "Gray"
Say ("USED                  : {0}" -f $usedCount) "Green"
Say ("UNUSED                : {0}" -f $unusedCount) "DarkYellow"

foreach ($row in $report | Sort-Object Api) {
    $color = if ($row.Status -eq "USED") { "Green" } else { "DarkYellow" }
    Say "`nAPI: $($row.Api)" $color
    Say "  Status: $($row.Status)" $color
    if ($row.Files) {
        Say "  Frontend files:" "Gray"
        $row.Files.Split("; ") | ForEach-Object {
            Say ("    - {0}" -f $_) "Gray"
        }
    } else {
        Say "  Frontend files: (none yet)" "DarkGray"
    }
}

# -------------------------------------------------
# 7) Save JSON snapshot
# -------------------------------------------------
$out = @{
    timestamp      = $Stamp
    base_url       = $BaseUrl
    canonical_apis = $CanonicalApis
    usage_map      = @{}
    report         = $report
}

foreach ($k in $usageMap.Keys) {
    $out.usage_map[$k] = $usageMap[$k]
}

$outFile = Join-Path $DiagDir ("nifdu_api_full_report_{0}.json" -f $Stamp)
($out | ConvertTo-Json -Depth 10) | Out-File $outFile -Encoding UTF8

Say ("`nReport JSON saved to: {0}" -f $outFile) "Yellow"
Say "`n=== NIFDU API FULL REPORT COMPLETE ===`n" "Cyan"
