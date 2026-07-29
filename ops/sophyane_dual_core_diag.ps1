# ==============================================
# C:\nifdu\ops\sophyane_dual_core_diag.ps1
# SOPHYANE / NIFDU — DUAL-CORE HEALTHCHECK
# ----------------------------------------------
# Checks:
#   1) Next.js UI  (http://localhost:3001/)
#   2) Agent3 proxy (http://localhost:3001/api/sophyane/chat)
#   3) Root via Caddy  (https://sophyane.com/)
#   4) Raw Lab via Caddy (/apps/vibe_static_lab/)
# ==============================================

param()

$ErrorActionPreference = "Continue"

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

Say "`n=== SOPHYANE / NIFDU DUAL-CORE DIAG ===`n" "Yellow"

$ok = @{
    "next_root"  = $false
    "next_api"   = $false
    "caddy_root" = $false
    "caddy_apps" = $false
}

# 1) Next.js root
Say "1) Next.js root -> http://localhost:3001/ ..." "Cyan"
try {
    $res = Invoke-WebRequest -Uri "http://localhost:3001/" -UseBasicParsing -TimeoutSec 5
    Say ("   Status: {0}" -f $res.StatusCode) "Green"
    if ($res.StatusCode -eq 200) { $ok["next_root"] = $true }
} catch {
    Say ("   FAILED: {0}" -f $_.Exception.Message) "Red"
}

# 2) Next.js Agent3 proxy
Say "`n2) Next.js -> /api/sophyane/chat -> NIFDU /api/chat ..." "Cyan"
try {
    $body = @{
        project = "sophyane_live"
        mode    = "vibe_coding"
        brain   = "auto"
        prompt  = "Healthcheck from sophyane_dual_core_diag.ps1"
    } | ConvertTo-Json -Depth 5

    $resApi = Invoke-RestMethod `
        -Uri "http://localhost:3001/api/sophyane/chat" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $jsonPreview = ($resApi | ConvertTo-Json -Depth 5)
    $previewLen = [Math]::Min(200, $jsonPreview.Length)
    Say "   OK: received JSON from Agent 3 proxy." "Green"
    Say ("   Preview: {0}" -f $jsonPreview.Substring(0, $previewLen)) "DarkGray"

    $ok["next_api"] = $true
} catch {
    Say ("   FAILED: {0}" -f $_.Exception.Message) "Red"
}

# Accept all certs + force modern TLS for HTTPS probes
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.SecurityProtocolType]::Tls12 -bor
    [System.Net.SecurityProtocolType]::Tls11 -bor
    [System.Net.SecurityProtocolType]::Tls

# 3) Root via Caddy
Say "`n3) Caddy -> https://sophyane.com/ (via 127.0.0.1) ..." "Cyan"
try {
    $resRoot = Invoke-WebRequest `
        -Uri "https://127.0.0.1/" `
        -Headers @{ Host = "sophyane.com" } `
        -UseBasicParsing `
        -TimeoutSec 8

    Say ("   HTTPS Status: {0}" -f $resRoot.StatusCode) "Green"
    if ($resRoot.StatusCode -eq 200) { $ok["caddy_root"] = $true }
} catch {
    Say ("   FAILED: {0}" -f $_.Exception.Message) "Red"
}

# 4) Raw Lab via Caddy /apps/vibe_static_lab/
Say "`n4) Caddy -> /apps/vibe_static_lab/ -> NIFDU /apps ..." "Cyan"
try {
    $resApps = Invoke-WebRequest `
        -Uri "https://127.0.0.1/apps/vibe_static_lab/" `
        -Headers @{ Host = "sophyane.com" } `
        -UseBasicParsing `
        -TimeoutSec 8

    Say ("   HTTPS Status: {0}" -f $resApps.StatusCode) "Green"

    # Only attempt snippet if Content exists and looks like a string
    if ($resApps -and $resApps.Content -and $resApps.Content.Length -gt 0) {
        $snippetLen = [Math]::Min(160, $resApps.Content.Length)
        $snippet = $resApps.Content.Substring(0, $snippetLen)
        Say "   Snippet:" "DarkGray"
        Say "   $snippet" "DarkGray"
    } else {
        Say "   (No body content / snippet not available)" "DarkGray"
    }

    if ($resApps.StatusCode -eq 200) { $ok["caddy_apps"] = $true }
} catch {
    Say ("   FAILED: {0}" -f $_.Exception.Message) "Red"
}

# Summary
Say "`n=== SUMMARY ===" "Yellow"
foreach ($k in $ok.Keys) {
    $status = if ($ok[$k]) { "OK" } else { "FAIL" }
    $color  = if ($ok[$k]) { "Green" } else { "Red" }
    Say ("  {0,-12} : {1}" -f $k, $status) $color
}

if ($ok.Values -notcontains $false) {
    Say "`nALL GREEN — Dual-Core Sophyane + NIFDU loop is healthy. 🚀`n" "Green"
} else {
    Say "`nSome checks FAILED — see above and fix those components.`n" "Red"
}
