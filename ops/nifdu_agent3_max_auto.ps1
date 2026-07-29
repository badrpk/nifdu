param(
    [Parameter(Mandatory=$true)]
    [string]$Project,                # e.g. react_todo_tailwind_full

    [string]$Port      = "3000",     # Dev port (Vite will be forced to this)
    [switch]$SkipBuild                # If set, skip npm run build selftest
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
    } catch { Write-Host $m }
}

$AppDir          = "C:\nifdu\src\apps\$Project"
$SelfTestScript  = "C:\nifdu\ops\nifdu_agent3_selftest.ps1"
$WebProbeScript  = "C:\nifdu\ops\nifdu_agent3_webprobe.ps1"

Say ""
Say "=== NIFDU AGENT 3 MAX-AUTO FLOW ===" "Cyan"
Say ("Project : {0}" -f $Project) "Gray"
Say ("AppDir  : {0}" -f $AppDir)  "Gray"
Say ("Port    : {0}" -f $Port)    "Gray"

if (!(Test-Path $AppDir -PathType Container)) {
    Say "[FATAL] AppDir not found." "Red"
    exit 1
}
if (!(Test-Path $SelfTestScript)) {
    Say "[FATAL] Selftest script missing: $SelfTestScript" "Red"
    exit 1
}
if (!(Test-Path $WebProbeScript)) {
    Say "[FATAL] Web probe script missing: $WebProbeScript" "Red"
    exit 1
}

# 1) Run selftest (npm run build) unless skipped
if (-not $SkipBuild) {
    Say ""
    Say "[1] Running self-test: npm run build..." "Yellow"

    powershell -ExecutionPolicy Bypass `
        -File $SelfTestScript `
        -Project $Project `
        -TestCommand "npm run build" `
        -MaxCycles 3

    if ($LASTEXITCODE -ne 0) {
        Say ("[FATAL] Self-test failed with exit code {0}." -f $LASTEXITCODE) "Red"
        exit $LASTEXITCODE
    }

    Say "[1] Self-test PASSED." "Green"
} else {
    Say "[1] Skipping self-test as requested." "DarkYellow"
}

# 2) Start dev server (npm run dev) in a new window, forcing the chosen port
Say ""
Say ("[2] Starting dev server on port {0} (npm run dev -- --port {0}) in a new window..." -f $Port) "Yellow"
Push-Location $AppDir
$devCmd = "npm run dev -- --port $Port"
Start-Process -FilePath "cmd.exe" -ArgumentList "/k $devCmd"
Pop-Location

# Give dev server a few seconds to start
Say "  -> Waiting a few seconds for dev server to boot..." "Gray"
Start-Sleep -Seconds 8

# 3) Web probe to verify app is reachable and rendering expected text
Say ""
$Url = "http://localhost:$Port/"
Say ("[3] Probing app at {0} ..." -f $Url) "Yellow"

powershell -ExecutionPolicy Bypass `
    -File $WebProbeScript `
    -Url $Url `
    -ExpectText "NIFDU React Todo"

if ($LASTEXITCODE -eq 0) {
    Say ""
    Say "=== MAX-AUTO FLOW COMPLETE: APP HEALTHY ===" "Green"
    Say ("Open in browser: {0}" -f $Url) "Green"
} else {
    Say ""
    Say "=== MAX-AUTO FLOW COMPLETE: PROBE FAILED ===" "Yellow"
    Say "Check dev server window and app logs for details." "DarkYellow"
}
