param()

$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$Text,
        [string]$Color = "Gray"
    )
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

$caddyDir      = "C:\caddy"
$caddyExe      = "C:\caddy\caddy.exe"
$caddyfilePath = "C:\caddy\Caddyfile"
$caddyBackup   = "C:\caddy\Caddyfile.backup_sophyane"

Say ""
Say "=== NIFDU / SOPHYANE — CADDY VHOST ONE-SHOT (PATCH MODE) ===" "Yellow"

# ----------------------------------------------------
# 1) Sanity checks
# ----------------------------------------------------
if (-not (Test-Path $caddyExe)) {
    Say ("ERROR: caddy.exe not found at {0}" -f $caddyExe) "Red"
    exit 1
}

if (-not (Test-Path $caddyfilePath)) {
    Say ("ERROR: Caddyfile not found at {0}" -f $caddyfilePath) "Red"
    exit 1
}

# ----------------------------------------------------
# 2) Backup Caddyfile
# ----------------------------------------------------
if (-not (Test-Path $caddyBackup)) {
    Say ("Backing up Caddyfile to: {0}" -f $caddyBackup) "DarkCyan"
    Copy-Item -Path $caddyfilePath -Destination $caddyBackup -Force
} else {
    Say ("Backup already exists: {0}" -f $caddyBackup) "DarkGray"
}

# ----------------------------------------------------
# 3) Append vhost if not already present
# ----------------------------------------------------
$caddyText = Get-Content -Path $caddyfilePath -Raw

if ($caddyText -match "sophyane\.com") {
    Say "Detected existing sophyane.com config in Caddyfile, not adding duplicate." "Yellow"
} else {
    Say "Appending sophyane.com + www.sophyane.com vhost to Caddyfile..." "Cyan"

    # IMPORTANT: plain here-string, no variables inside
    $block = @"

sophyane.com, www.sophyane.com {
    encode gzip
    reverse_proxy 127.0.0.1:8000
}

"@

    Add-Content -Path $caddyfilePath -Value $block
    Say "Caddyfile updated with Sophyane vhost." "Green"
}

# ----------------------------------------------------
# 4) Reload Caddy
# ----------------------------------------------------
Say "Reloading Caddy with new config..." "Cyan"
Push-Location $caddyDir
try {
    & $caddyExe reload --config $caddyfilePath
    Say "Caddy reload requested." "Green"
} catch {
    Say ("ERROR reloading Caddy: {0}" -f $_.Exception.Message) "Red"
}
Pop-Location

Start-Sleep -Seconds 2

# ----------------------------------------------------
# 5) Smoke tests (HTTP and HTTPS)
# ----------------------------------------------------
function Test-Url {
    param(
        [string]$Url,
        [switch]$Https
    )

    try {
        if ($Https) {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop
        } else {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
        }

        $snippetLen = [Math]::Min(200, $resp.Content.Length)
        $snippet = $resp.Content.Substring(0, $snippetLen)

        Say ("URL: {0}" -f $Url) "Cyan"
        Say ("StatusCode: {0}" -f $resp.StatusCode) "Green"
        Say "Snippet:" "Gray"
        Say $snippet "Gray"
        Say "----" "DarkGray"
    } catch {
        Say ("URL: {0}" -f $Url) "Cyan"
        Say ("ERROR: {0}" -f $_.Exception.Message) "Red"
        Say "----" "DarkGray"
    }
}

Say ""
Say "=== SMOKE TEST — HTTP/HTTPS for sophyane.com ===" "Yellow"

Test-Url "http://sophyane.com/"
Test-Url "http://www.sophyane.com/"

Test-Url "https://sophyane.com/" -Https
Test-Url "https://www.sophyane.com/" -Https

Say ""
Say "=== DONE: SOPHYANE.COM VHOST WIRED TO NIFDU:8000 ===" "Yellow"
Say ""
