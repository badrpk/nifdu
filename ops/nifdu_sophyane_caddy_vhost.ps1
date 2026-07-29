# ==============================================
# C:\nifdu\ops\nifdu_sophyane_caddy_vhost.ps1
# NIFDU / SOPHYANE — CADDY VHOST ONE-SHOT
# ----------------------------------------------
# Goal:
#   - Append a site block for sophyane.com
#   - Proxy all traffic to the local Next.js app on :3000
#
# Usage:
#   cd C:\nifdu\ops
#   powershell -ExecutionPolicy Bypass `
#     -File .\nifdu_sophyane_caddy_vhost.ps1
# ==============================================

param(
    [string]$Domain        = "sophyane.com",
    [string]$CaddyfilePath = "C:\caddy\Caddyfile"
)

$ErrorActionPreference = "Stop"

Write-Host "=== NIFDU / SOPHYANE — CADDY VHOST ONE-SHOT ===" -ForegroundColor Yellow
Write-Host "Domain: $Domain" -ForegroundColor Gray
Write-Host "Caddyfile: $CaddyfilePath" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $CaddyfilePath)) {
    Write-Host "ERROR: Caddyfile not found at $CaddyfilePath" -ForegroundColor Red
    Write-Host "Make sure Caddy is installed in C:\caddy and has a Caddyfile." -ForegroundColor Red
    exit 1
}

# Backup existing Caddyfile
$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$CaddyfilePath.$timestamp.bak"

Copy-Item -Path $CaddyfilePath -Destination $backupPath -Force
Write-Host "Backup created: $backupPath" -ForegroundColor DarkYellow

# Define Sophyane site block (no PowerShell syntax inside)
$siteBlock = @"
# ==========================================
# Sophyane — Vibe Coding Studio
# Proxies sophyane.com -> Next.js on :3000
# ==========================================
$Domain, www.$Domain {
    encode zstd gzip
    reverse_proxy 127.0.0.1:3000
}
"@

Write-Host "Appending Sophyane vhost block to Caddyfile..." -ForegroundColor Cyan
"`r`n$siteBlock`r`n" | Add-Content -Path $CaddyfilePath -Encoding UTF8
Write-Host "Caddyfile updated." -ForegroundColor Green

# Reload Caddy if present
if (Test-Path "C:\caddy\caddy.exe") {
    Write-Host "Attempting to reload Caddy with new config..." -ForegroundColor Cyan
    Push-Location "C:\caddy"
    try {
        .\caddy.exe reload --config $CaddyfilePath
        Write-Host "Caddy reload command issued." -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Caddy reload failed. Check if Caddy is running as a service." -ForegroundColor DarkYellow
        Write-Host $_.Exception.Message -ForegroundColor DarkYellow
    }
    Pop-Location
} else {
    Write-Host "NOTE: C:\caddy\caddy.exe not found. Skipping reload step." -ForegroundColor DarkYellow
    Write-Host "If Caddy runs as a service, it may auto-reload, or you can reload manually." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Yellow
Write-Host "If DNS for $Domain points to this machine's public IP," -ForegroundColor Gray
Write-Host "Caddy will terminate TLS and proxy traffic to http://127.0.0.1:3000." -ForegroundColor Gray
