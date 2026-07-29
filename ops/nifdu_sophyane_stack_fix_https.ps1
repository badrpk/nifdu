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

$nifduExe  = "C:\nifdu\build\Release\nifdu.exe"
$caddyExe  = "C:\caddy\caddy.exe"
$caddyfile = "C:\caddy\Caddyfile"

Say ""
Say "=== NIFDU / SOPHYANE STACK DIAG + FIX (HTTPS) ===" "Yellow"

# ----------------------------------------------------
# 1) Check NIFDU process + port 8000
# ----------------------------------------------------
$nifdu = Get-Process -Name nifdu -ErrorAction SilentlyContinue
if ($nifdu) {
    Say ("[NIFDU] Process running: PID={0}" -f $nifdu.Id) "Green"
} else {
    Say "[NIFDU] Not running. Starting..." "DarkYellow"
    if (-not (Test-Path $nifduExe)) {
        Say ("[NIFDU] ERROR: nifdu.exe not found at {0}" -f $nifduExe) "Red"
    } else {
        Start-Process $nifduExe
        Start-Sleep -Seconds 3
        $nifdu = Get-Process -Name nifdu -ErrorAction SilentlyContinue
        if ($nifdu) {
            Say ("[NIFDU] Started: PID={0}" -f $nifdu.Id) "Green"
        } else {
            Say "[NIFDU] ERROR: Failed to start nifdu.exe" "Red"
        }
    }
}

Say "[NIFDU] Checking port 8000 listeners..." "Cyan"
$port8000 = netstat -ano | Select-String ":8000 " | Select-String "LISTENING" -ErrorAction SilentlyContinue
if ($port8000) {
    $line    = $port8000.ToString()
    $parts   = $line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    $pidNum  = $parts[-1]
    $proc    = $null
    try { $proc = Get-Process -Id $pidNum -ErrorAction Stop } catch {}
    if ($proc) {
        Say ("[NIFDU] Port 8000 LISTENING by PID={0} ({1})" -f $pidNum, $proc.ProcessName) "Green"
    } else {
        Say ("[NIFDU] Port 8000 LISTENING by unknown PID={0}" -f $pidNum) "Yellow"
    }
} else {
    Say "[NIFDU] WARNING: No LISTENING entry for port 8000" "Yellow"
}

# ----------------------------------------------------
# 2) Check Caddy process + ports 80/443
# ----------------------------------------------------
$caddy = Get-Process -Name caddy -ErrorAction SilentlyContinue
if ($caddy) {
    Say ("[CADDY] Process running: PID={0}" -f $caddy.Id) "Green"
} else {
    Say "[CADDY] Not running. Starting with Caddyfile..." "DarkYellow"
    if (-not (Test-Path $caddyExe)) {
        Say ("[CADDY] ERROR: caddy.exe not found at {0}" -f $caddyExe) "Red"
    } elseif (-not (Test-Path $caddyfile)) {
        Say ("[CADDY] ERROR: Caddyfile not found at {0}" -f $caddyfile) "Red"
    } else {
        Start-Process $caddyExe -ArgumentList @("run","--config",$caddyfile)
        Start-Sleep -Seconds 5
        $caddy = Get-Process -Name caddy -ErrorAction SilentlyContinue
        if ($caddy) {
            Say ("[CADDY] Started: PID={0}" -f $caddy.Id) "Green"
        } else {
            Say "[CADDY] ERROR: Failed to start caddy.exe" "Red"
        }
    }
}

Say "[CADDY] Checking ports 80 and 443 listeners..." "Cyan"
$port80  = netstat -ano | Select-String ":80 "  | Select-String "LISTENING" -ErrorAction SilentlyContinue
$port443 = netstat -ano | Select-String ":443 " | Select-String "LISTENING" -ErrorAction SilentlyContinue

if ($port80) {
    $line    = $port80.ToString()
    $parts   = $line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    $pidNum  = $parts[-1]
    $proc    = $null
    try { $proc = Get-Process -Id $pidNum -ErrorAction Stop } catch {}
    if ($proc) {
        Say ("[CADDY] Port 80 LISTENING by PID={0} ({1})" -f $pidNum, $proc.ProcessName) "Green"
    } else {
        Say ("[CADDY] Port 80 LISTENING by unknown PID={0}" -f $pidNum) "Yellow"
    }
} else {
    Say "[CADDY] WARNING: No LISTENING entry for port 80" "Yellow"
}

if ($port443) {
    $line    = $port443.ToString()
    $parts   = $line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    $pidNum  = $parts[-1]
    $proc    = $null
    try { $proc = Get-Process -Id $pidNum -ErrorAction Stop } catch {}
    if ($proc) {
        Say ("[CADDY] Port 443 LISTENING by PID={0} ({1})" -f $pidNum, $proc.ProcessName) "Green"
    } else {
        Say ("[CADDY] Port 443 LISTENING by unknown PID={0}" -f $pidNum) "Yellow"
    }
} else {
    Say "[CADDY] WARNING: No LISTENING entry for port 443" "Yellow"
}

# ----------------------------------------------------
# 3) End-to-end smoke tests via Caddy -> NIFDU
# ----------------------------------------------------
function Test-Url {
    param(
        [string]$Label,
        [string]$Url,
        [switch]$Https
    )

    Say ("[TEST] {0} => {1}" -f $Label, $Url) "Cyan"
    try {
        if ($Https) {
            $resp = Invoke-WebRequest -Uri $Url -Headers @{ Host = "sophyane.com" } -SkipCertificateCheck -UseBasicParsing -ErrorAction Stop
        } else {
            $resp = Invoke-WebRequest -Uri $Url -Headers @{ Host = "sophyane.com" } -UseBasicParsing -ErrorAction Stop
        }

        $snippetLen = [Math]::Min(200, $resp.Content.Length)
        $snippet = $resp.Content.Substring(0, $snippetLen)

        Say ("StatusCode: {0}" -f $resp.StatusCode) "Green"
        Say "Snippet:" "Gray"
        Say $snippet "Gray"
    } catch {
        Say ("ERROR: {0}" -f $_.Exception.Message) "Red"
    }
    Say "----" "DarkGray"
}

Say ""
Say "=== SMOKE TESTS: CADDY (127.0.0.1) -> NIFDU (8000) ===" "Yellow"

Test-Url -Label "Root UI (HTTPS)" -Url "https://127.0.0.1/" -Https
Test-Url -Label "Dogs Karachi App (HTTPS)" -Url "https://127.0.0.1/apps/dogs_karachi_site/" -Https

Say ""
Say "=== DONE NIFDU / SOPHYANE STACK DIAG + FIX ===" "Yellow"
Say ""
