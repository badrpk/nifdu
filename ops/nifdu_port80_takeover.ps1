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

$ExePath  = "C:\nifdu\build\Release\nifdu.exe"

Say ""
Say "=== NIFDU PORT 80 TAKEOVER ===" "Yellow"
Say "" "Yellow"

# ---------------------------------------------------------
# STEP 1: Show current listeners on port 80
# ---------------------------------------------------------
Say "[1/5] Current listeners on TCP port 80:" "Cyan"

$listeners = @()

try {
    $listeners = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction Stop
} catch {
    Say "Get-NetTCPConnection not available, falling back to netstat..." "DarkYellow"
}

if (-not $listeners -or $listeners.Count -eq 0) {
    # fallback: netstat
    $netstat = netstat -ano | Select-String "LISTENING" | Select-String ":80 "
    if ($netstat) {
        $tmp = @()
        foreach ($line in $netstat) {
            $parts = $line.ToString().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($parts.Count -lt 5) { continue }
            $pid   = [int]$parts[-1]
            $addr  = $parts[1]
            try {
                $proc = Get-Process -Id $pid -ErrorAction Stop
                $pname = $proc.ProcessName
            } catch {
                $pname = "<unknown>"
            }
            $tmp += [PSCustomObject]@{
                LocalAddress  = $addr.Split(":")[0]
                LocalPort     = 80
                OwningProcess = $pid
                ProcessName   = $pname
            }
        }
        $listeners = $tmp
    }
}

if ($listeners -and $listeners.Count -gt 0) {
    $listeners | Format-Table -AutoSize
} else {
    Say "No listeners on port 80 detected." "Green"
}

# ---------------------------------------------------------
# STEP 2: Kill any non-NIFDU user-space listeners on 80
# ---------------------------------------------------------
Say ""
Say "[2/5] Stopping non-NIFDU processes on port 80 (except System)..." "Cyan"

$killed = @()

foreach ($l in $listeners) {
    $pid  = $l.OwningProcess
    $name = $l.ProcessName

    # Skip nifdu itself and System PID 4
    if ($name -eq "nifdu" -or $pid -eq 4) {
        Say "  Keeping PID $pid ($name) on 80." "DarkGreen"
        continue
    }

    if ($pid -and $pid -gt 0) {
        try {
            Say "  Killing PID $pid ($name) listening on 80..." "DarkYellow"
            Stop-Process -Id $pid -Force -ErrorAction Stop
            $killed += $pid
        } catch {
            Say "  [WARN] Failed to stop PID $pid ($name): $_" "Red"
        }
    }
}

if ($killed.Count -eq 0) {
    Say "  No non-NIFDU user-space listeners were stopped." "DarkGray"
} else {
    Say "  Stopped PIDs: $($killed -join ', ')" "Green"
}

# ---------------------------------------------------------
# STEP 3: If System (PID 4) owns 80 via portproxy, remove rules
# ---------------------------------------------------------
Say ""
Say "[3/5] Checking for portproxy rules on port 80..." "Cyan"

try {
    $pp = netsh interface portproxy show v4tov4
    $pp80 = $pp | Select-String " 80 "
    if ($pp80) {
        Say "  Portproxy rules mentioning 80 detected:" "DarkYellow"
        $pp80 | ForEach-Object { Say ("    " + $_) "DarkYellow" }

        foreach ($addr in @("0.0.0.0","127.0.0.1")) {
            try {
                Say "  Removing portproxy listenport=80 listenaddress=$addr ..." "DarkYellow"
                netsh interface portproxy delete v4tov4 listenport=80 listenaddress=$addr | Out-Null
            } catch {
                # ignore errors
            }
        }

        Say "  Portproxy cleanup step done." "Green"
    } else {
        Say "  No portproxy entries referencing 80." "DarkGray"
    }
} catch {
    Say "  [WARN] Could not query portproxy rules: $_" "Red"
}

# ---------------------------------------------------------
# STEP 4: Restart nifdu.exe cleanly
# ---------------------------------------------------------
Say ""
Say "[4/5] Restarting nifdu.exe as sole port 80 owner..." "Cyan"

Get-Process nifdu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if (!(Test-Path $ExePath)) {
    Say "  [FATAL] nifdu.exe not found at $ExePath. Build NIFDU first." "Red"
    exit 1
}

Start-Process $ExePath
Say "  nifdu.exe started." "Green"

Start-Sleep -Seconds 4

# ---------------------------------------------------------
# STEP 5: Sanity check / and /api/chat
# ---------------------------------------------------------
Say ""
Say "[5/5] Sanity check root (/) and /api/chat ..." "Cyan"

try {
    $root = Invoke-WebRequest -Uri "http://127.0.0.1/" -UseBasicParsing -TimeoutSec 5
    $snippetLen = [Math]::Min(160, $root.Content.Length)
    $snippet = $root.Content.Substring(0, $snippetLen).Replace("`n"," ").Replace("`r"," ")
    Say "  GET /  => HTTP $($root.StatusCode)" "Green"
    Say "  First 160 chars of HTML: $snippet" "DarkGray"
} catch {
    Say "  [ERROR] GET / failed: $_" "Red"
}

try {
    $body = @{
        project = "nifdu_port80_smoketest"
        brain   = "auto"
        mode    = "vibe_coding"
        prompt  = "Just say: hello from NIFDU port-80 takeover smoke test."
    } | ConvertTo-Json -Depth 5

    $resp = Invoke-WebRequest -Uri "http://127.0.0.1/api/chat" `
                              -Method Post `
                              -ContentType "application/json" `
                              -Body $body `
                              -TimeoutSec 15

    Say "  POST /api/chat => HTTP $($resp.StatusCode)" "Green"
    $snippetLen2 = [Math]::Min(200, $resp.Content.Length)
    $jsonSnippet = $resp.Content.Substring(0, $snippetLen2).Replace("`n"," ").Replace("`r"," ")
    Say "  First 200 chars of JSON: $jsonSnippet" "DarkGray"
} catch {
    Say "  [ERROR] POST /api/chat failed: $_" "Red"
}

Say ""
Say "=== PORT 80 TAKEOVER COMPLETE ===" "Yellow"
Say "Now reload http://127.0.0.1/ in Chrome and test the button again." "Yellow"
Say ""
