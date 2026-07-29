param()
$ErrorActionPreference = "Stop"

$CADDYFILE = "C:\caddy\Caddyfile"
$CADDYEXE  = "C:\caddy\caddy.exe"

Write-Host "`n=== FORCE CLEAN SOPHYANE CADDY BLOCK ===`n" -ForegroundColor Yellow

if (!(Test-Path $CADDYFILE)) {
    throw "Missing Caddyfile"
}

$bak = "$CADDYFILE.bak_forceclean_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $CADDYFILE $bak -Force
Write-Host "Backup -> $bak" -ForegroundColor DarkGray

$cleanBlock = @"
sophyane.com, www.sophyane.com {

    encode gzip zstd

    handle_path /api/* {
        reverse_proxy 127.0.0.1:8000
    }

    handle /socket* {
        reverse_proxy 127.0.0.1:3000
    }

    handle {
        reverse_proxy 127.0.0.1:3000
    }
}
"@

$cf = Get-Content $CADDYFILE -Raw

# Remove ANY existing sophyane.com block entirely
$cf = [regex]::Replace(
    $cf,
    '(?ms)^sophyane\.com\s*,\s*www\.sophyane\.com\s*\{.*?\}',
    ''
)

$cf = $cf.Trim() + "`r`n`r`n" + $cleanBlock

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($CADDYFILE, $cf, $utf8NoBom)

Write-Host "Caddyfile rewritten safely." -ForegroundColor Green

Write-Host "`nRestarting Caddy..." -ForegroundColor Cyan
Get-Process caddy -EA SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
Start-Process $CADDYEXE -ArgumentList @("run","--config",$CADDYFILE,"--adapter","caddyfile")

Start-Sleep -Milliseconds 1000

Write-Host "`nListeners:" -ForegroundColor Cyan
Get-NetTCPConnection -State Listen -LocalPort 80,443 |
    ForEach-Object {
        $p = Get-Process -Id $_.OwningProcess -EA SilentlyContinue
        "{0} -> {1}" -f $_.LocalPort, $p.Path
    }

Write-Host "`nDONE." -ForegroundColor Green
