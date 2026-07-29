# ==============================================
# C:\nifdu\ops\nifdu_sophyane_caddy_fix_oneshot.ps1
# SIMPLE NIFDU -> Caddy wiring for sophyane.com
# - Rewrites Caddyfile with ONLY sophyane.com vhost
# - /api/* -> http://127.0.0.1:8000
# - Static root: C:\webroot\sophyane.com\www
# - Validates + reloads Caddy
# - Small smoke tests
# ==============================================

param()

$ErrorActionPreference = "Stop"

$caddyDir  = "C:\caddy"
$caddyExe  = Join-Path $caddyDir "caddy.exe"
$caddyFile = Join-Path $caddyDir "Caddyfile"

Write-Host ""
Write-Host "=== SIMPLE SOPHYANE CADDY FIX ===" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $caddyExe)) {
    Write-Host "ERROR: caddy.exe not found at $caddyExe" -ForegroundColor Red
    exit 1
}

if (Test-Path $caddyFile) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup    = "$caddyFile.bak_$timestamp"
    Copy-Item $caddyFile $backup -Force
    Write-Host "Backup created: $backup" -ForegroundColor DarkGreen
} else {
    Write-Host "No existing Caddyfile, will create a new one." -ForegroundColor DarkYellow
}

# Minimal Caddyfile: ONLY sophyane.com
$caddyConfig = @"
sophyane.com, www.sophyane.com {
    encode gzip

    @api path /api/*
    handle @api {
        reverse_proxy http://127.0.0.1:8000
    }

    handle {
        root * C:\webroot\sophyane.com\www
        file_server
    }
}
"@

# Write new Caddyfile
$caddyConfig | Set-Content -Path $caddyFile -Encoding UTF8
Write-Host "Caddyfile written with sophyane.com vhost." -ForegroundColor Green

# Validate and reload Caddy
Set-Location $caddyDir

Write-Host ""
Write-Host "Validating Caddyfile..." -ForegroundColor Yellow
& $caddyExe validate --config $caddyFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Caddyfile validation failed." -ForegroundColor Red
    exit 1
}
Write-Host "Caddyfile validation OK." -ForegroundColor Green

Write-Host "Reloading Caddy..." -ForegroundColor Yellow
& $caddyExe reload --config $caddyFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Caddy reload failed." -ForegroundColor Red
    exit 1
}
Write-Host "Caddy reloaded successfully." -ForegroundColor Green

# Quick ports view
Write-Host ""
Write-Host "=== PORT LISTENERS (80 / 443 / 8000) ===" -ForegroundColor Yellow
@('80','443','8000') | ForEach-Object {
    $p = $_
    Write-Host ("Port {0}:" -f $p) -ForegroundColor Cyan
    netstat -ano | Select-String ":$p " | Select-String "LISTENING"
}

# HTTPS smoke tests via sophyane.com (tiny output)
Write-Host ""
Write-Host "=== HTTPS SMOKE TEST via sophyane.com ===" -ForegroundColor Yellow

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

try {
    $health = Invoke-WebRequest `
        -Uri 'https://127.0.0.1/api/health' `
        -Headers @{ Host = 'sophyane.com' } `
        -UseBasicParsing

    Write-Host ("HTTPS /api/health => {0}" -f $health.StatusCode) -ForegroundColor Green
} catch {
    Write-Host ("ERROR /api/health: {0}" -f $_.Exception.Message) -ForegroundColor Red
}

$body = @{
    project = "vibe_web"
    prompt  = "make cat types website"
    brain   = "auto"
    mode    = "vibe_coding"
} | ConvertTo-Json -Depth 10

try {
    $chat = Invoke-WebRequest `
        -Uri 'https://127.0.0.1/api/chat' `
        -Headers @{ Host = 'sophyane.com' } `
        -Method Post `
        -ContentType 'application/json; charset=utf-8' `
        -UseBasicParsing `
        -Body $body

    Write-Host ("HTTPS /api/chat => {0}" -f $chat.StatusCode) -ForegroundColor Green
} catch {
    Write-Host ("ERROR /api/chat: {0}" -f $_.Exception.Message) -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DONE: sophyane.com /api/* -> http://127.0.0.1:8000 ===" -ForegroundColor Magenta
