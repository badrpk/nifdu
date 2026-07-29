# ==============================================
# C:\nifdu\ops\nifdu_fix_caddy_apps_backend.ps1
# NIFDU / SOPHYANE — AUTO-FIX CADDY @apps BACKEND
# ----------------------------------------------
# - Probes /apps/vibe_static_lab/ on 80 and 8000
# - Chooses working port
# - Rewrites @apps reverse_proxy backend in:
#     C:\caddy\Caddyfile
# - Reloads Caddy
# - Tests HTTPS /apps/vibe_static_lab/ via sophyane.com
# ==============================================

param()

$ErrorActionPreference = "Stop"

function Say {
    param([string]$Text, [string]$Color = "Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

Say "`n=== NIFDU /apps BACKEND AUTO-FIX ===`n" "Yellow"

# -------------------------------------------------
# 1) Probe ports 80 and 8000 for /apps/vibe_static_lab/
# -------------------------------------------------
$ports = 80, 8000
$workingPort = $null

foreach ($p in $ports) {
    Say "Probing http://127.0.0.1:$p/apps/vibe_static_lab/ ..." "Cyan"
    try {
        $res = Invoke-WebRequest `
            -Uri "http://127.0.0.1:$p/apps/vibe_static_lab/" `
            -UseBasicParsing -TimeoutSec 5
        Say ("  -> OK (Status {0})" -f $res.StatusCode) "Green"

        if ($res.StatusCode -eq 200 -and -not $workingPort) {
            $workingPort = $p
        }
    }
    catch {
        Say ("  -> FAILED: {0}" -f $_.Exception.Message) "Red"
    }
}

if (-not $workingPort) {
    Say "`nNo working backend found for /apps/vibe_static_lab/ on 80 or 8000." "Red"
    Say "Make sure nifdu.exe is running and serving /apps/*, then rerun this script." "Red"
    exit 1
}

Say ("`nSelected backend port: {0}" -f $workingPort) "Green"

# -------------------------------------------------
# 2) Rewrite @apps reverse_proxy line in Caddyfile
# -------------------------------------------------
$caddyDir   = "C:\caddy"
$caddyFile  = Join-Path $caddyDir "Caddyfile"

if (!(Test-Path $caddyFile)) {
    Say ("Caddyfile not found at {0}" -f $caddyFile) "Red"
    exit 1
}

Say ("Updating @apps backend in {0} ..." -f $caddyFile) "Yellow"

$lines = Get-Content $caddyFile

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "handle\s+@apps") {
        # Inside the @apps handle block, find reverse_proxy line
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j] -match "^\s*\}") {
                break
            }
            if ($lines[$j] -match "reverse_proxy\s+127\.0\.0\.1:") {
                $old = $lines[$j]
                $lines[$j] = $lines[$j] -replace "127\.0\.0\.1:\d+", "127.0.0.1:$workingPort"
                Say "  Found @apps reverse_proxy line:" "Cyan"
                Say "    OLD: $old" "DarkGray"
                Say "    NEW: $($lines[$j])" "Green"
                break
            }
        }
    }
}

# Backup and write
$backupPath = "$caddyFile.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $caddyFile $backupPath -Force
Say ("Backup written: {0}" -f $backupPath) "DarkGray"

$lines | Set-Content -Path $caddyFile -Encoding UTF8
Say "Caddyfile updated." "Green"

# -------------------------------------------------
# 3) Reload Caddy
# -------------------------------------------------
Say "`nReloading Caddy..." "Yellow"
Push-Location $caddyDir
try {
    & .\caddy.exe reload
    if ($LASTEXITCODE -ne 0) {
        Say ("caddy reload exited with code {0}" -f $LASTEXITCODE) "Red"
    } else {
        Say "Caddy reload OK." "Green"
    }
}
catch {
    Say ("Failed to reload Caddy: {0}" -f $_.Exception.Message) "Red"
}
Pop-Location

# -------------------------------------------------
# 4) Test HTTPS /apps/vibe_static_lab/ via sophyane.com
# -------------------------------------------------
Say "`nTesting HTTPS /apps/vibe_static_lab/ via sophyane.com ..." "Yellow"

try {
    $resHttps = Invoke-WebRequest `
        -Uri "https://127.0.0.1/apps/vibe_static_lab/" `
        -Headers @{ Host = "sophyane.com" } `
        -SkipCertificateCheck `
        -UseBasicParsing `
        -TimeoutSec 10

    Say ("  HTTPS Status: {0}" -f $resHttps.StatusCode) "Green"

    $snippet = $resHttps.Content.Substring(0, [Math]::Min(160, $resHttps.Content.Length))
    Say "  Snippet:" "DarkGray"
    Say "  $snippet" "DarkGray"
}
catch {
    Say ("  HTTPS probe FAILED: {0}" -f $_.Exception.Message) "Red"
}

Say "`n=== DONE: @apps backend aligned with NIFDU ===`n" "Green"
