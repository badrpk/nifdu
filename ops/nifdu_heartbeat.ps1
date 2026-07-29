# ==============================================
# C:\nifdu\ops\nifdu_heartbeat.ps1
# NIFDU MONOLITH 2.0 HEARTBEAT
# ==============================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

Say ""
Say "=== NIFDU MONOLITH 2.0 HEARTBEAT ===" "Yellow"
Say ""

$Root = "C:\nifdu"
$Ops  = Join-Path $Root "ops"

$Boot = Join-Path $Ops "nifdu_boot_and_surface.ps1"
$Scan = Join-Path $Ops "nifdu_vibe_foundation_scan.ps1"

if (!(Test-Path $Boot)) {
    Say "[FATAL] Missing " "Red"
    exit 1
}

if (!(Test-Path $Scan)) {
    Say "[FATAL] Missing " "Red"
    exit 1
}

$bootOK = $false
$scanOK = $false

Say "[STEP 1] Boot + HTTP surface check" "Cyan"
try {
    & $Boot
    $bootOK = $true
    Say "[OK] HTTP surface healthy" "Green"
} catch {
    Say "[FAIL] Boot/surface failed" "Red"
}

Say ""
Say "[STEP 2] Foundation scan" "Cyan"
try {
    & $Scan
    $scanOK = $true
    Say "[OK] Foundation scan healthy" "Green"
} catch {
    Say "[FAIL] Foundation scan failed" "Red"
}

Say ""
Say "--- HEARTBEAT VERDICT ---" "Yellow"

if ($bootOK -and $scanOK) {
    Say "NIFDU MONOLITH 2.0 STATUS: HEALTHY" "Green"
    Say "HTTP surface OK | C++ APIs OK" "Green"
}
elseif ($bootOK) {
    Say "STATUS: PARTIAL (runtime OK, scan failed)" "DarkYellow"
}
elseif ($scanOK) {
    Say "STATUS: PARTIAL (scan OK, runtime failed)" "DarkYellow"
}
else {
    Say "STATUS: DEGRADED" "Red"
}

Say ""
Say "=== HEARTBEAT COMPLETE ===" "Yellow"
