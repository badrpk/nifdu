# ==============================================
# C:\nifdu\ops\nifdu_move_http_to_8000.ps1
# Move NIFDU HTTP server from port 80 -> 8000
# ----------------------------------------------
# 1) Patch C++ HTTP server source to use port 8000 instead of 80
#    - Tries multiple patterns:
#        tcp::endpoint(tcp::v4(), 80)
#        constexpr unsigned short PORT = 80;
#        constexpr unsigned short HTTP_PORT = 80;
#        any line mentioning 'port' or 'PORT' with '= 80;'
# 2) Backup original .cpp file
# 3) Rebuild NIFDU (Release)
# 4) Restart nifdu.exe
# 5) Show that port 8000 is now listening
# ==============================================

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

Say "`n=== NIFDU HTTP PORT MOVE (80 -> 8000) ONE-SHOT v2 ===`n" "Yellow"

# ----------------------------------------------
# 1) Paths / files
# ----------------------------------------------
$RepoRoot   = "C:\nifdu"
$BuildDir   = "C:\nifdu\build"
$ExePath    = "C:\nifdu\build\Release\nifdu.exe"
$HttpFile   = "C:\nifdu\src\http\nifdu_http_server80.cpp"   # adjust if different

if (-not (Test-Path $HttpFile)) {
    Say "ERROR: HTTP server source not found at: $HttpFile" "Red"
    Say "Adjust `$HttpFile in the script if your file is in another path." "Red"
    exit 1
}

Say "HTTP server file: $HttpFile" "Cyan"

# ----------------------------------------------
# 2) Backup the file
# ----------------------------------------------
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup    = "$HttpFile.bak_$timestamp"

Say "Backing up original file to: $backup" "DarkGray"
Copy-Item $HttpFile $backup -Force

# ----------------------------------------------
# 3) Patch port 80 -> 8000 in the source
# ----------------------------------------------
Say "Patching C++ source ports (80 -> 8000)..." "Cyan"

$content = Get-Content $HttpFile -Raw
$original = $content
$replacements = 0

# Pattern 1: direct Boost.Beast acceptor endpoint
#   tcp::endpoint(tcp::v4(), 80)
$patternEndpoint = 'tcp::endpoint\s*\(\s*tcp::v4\(\)\s*,\s*80\s*\)'
if ($content -match $patternEndpoint) {
    $content = [regex]::Replace(
        $content,
        $patternEndpoint,
        'tcp::endpoint(tcp::v4(), 8000)'
    )
    $replacements++
    Say " - Replaced tcp::endpoint(tcp::v4(), 80) -> 8000" "Green"
} else {
    Say " - No direct tcp::endpoint(..., 80) pattern found." "DarkGray"
}

# Pattern 2: constexpr unsigned short PORT = 80;
$patternConstPort = 'constexpr\s+unsigned\s+short\s+PORT\s*=\s*80\s*;'
if ($content -match $patternConstPort) {
    $content = [regex]::Replace(
        $content,
        $patternConstPort,
        'constexpr unsigned short PORT = 8000;'
    )
    $replacements++
    Say " - Replaced constexpr unsigned short PORT = 80; -> 8000" "Green"
} else {
    Say " - No constexpr unsigned short PORT = 80; pattern found." "DarkGray"
}

# Pattern 3: constexpr unsigned short HTTP_PORT = 80;
$patternConstHttpPort = 'constexpr\s+unsigned\s+short\s+HTTP_PORT\s*=\s*80\s*;'
if ($content -match $patternConstHttpPort) {
    $content = [regex]::Replace(
        $content,
        $patternConstHttpPort,
        'constexpr unsigned short HTTP_PORT = 8000;'
    )
    $replacements++
    Say " - Replaced constexpr unsigned short HTTP_PORT = 80; -> 8000" "Green"
} else {
    Say " - No constexpr unsigned short HTTP_PORT = 80; pattern found." "DarkGray"
}

# Pattern 4: any line mentioning 'port' or 'PORT' with '= 80;'
if ($replacements -eq 0) {
    Say " - Trying generic 'port = 80' style replacements..." "DarkGray"
    $lines = $content -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '(port|PORT)' -and $line -match '=\s*80\s*;') {
            Say ("   • Before: " + $line.Trim()) "DarkGray"
            $lines[$i] = [regex]::Replace($line, '=\s*80\s*;', '= 8000;')
            Say ("     After : " + $lines[$i].Trim()) "Green"
            $replacements++
        }
    }
    $content = ($lines -join "`r`n")
}

if ($replacements -eq 0) {
    Say "`nWARNING: No port 80 patterns were changed in $HttpFile" "Yellow"
    Say "The file may define its port elsewhere or via config/env." "Yellow"
} else {
    if ($content -ne $original) {
        Set-Content -Path $HttpFile -Value $content -Encoding UTF8
        Say "`nTotal replacements: $replacements (file updated)" "Green"
    } else {
        Say "`nReplacements counter > 0 but content unchanged – check logic." "Yellow"
    }
}

# ----------------------------------------------
# 4) Rebuild NIFDU (Release)
# ----------------------------------------------
if (-not (Test-Path $BuildDir)) {
    Say "ERROR: Build directory not found: $BuildDir" "Red"
    exit 1
}

Say "`nBuilding NIFDU (Release)..." "Cyan"
Push-Location $BuildDir
cmake --build . --config Release
Pop-Location

# ----------------------------------------------
# 5) Restart nifdu.exe
# ----------------------------------------------
Say "`nRestarting nifdu.exe..." "Cyan"

Get-Process -Name "nifdu" -ErrorAction SilentlyContinue | ForEach-Object {
    Say ("Stopping existing nifdu.exe (PID {0})" -f $_.Id) "DarkGray"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $ExePath)) {
    Say "ERROR: nifdu.exe not found at: $ExePath" "Red"
    exit 1
}

Start-Process $ExePath
Say "Started nifdu.exe from $ExePath" "Green"

Start-Sleep -Seconds 3

# ----------------------------------------------
# 6) Verify listeners and basic /api health on :8000
# ----------------------------------------------
Say "`nChecking port listeners for 8000:" "Cyan"
$lines8000 = netstat -ano | Select-String "LISTENING" | Select-String ":8000 "
if ($lines8000) {
    foreach ($l in $lines8000) {
        $parts  = $l.ToString().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
        $procId = $parts[-1]   # use different name to avoid $PID clash
        try {
            $proc = Get-Process -Id $procId -ErrorAction Stop
            Say ("  {0} (PID {1})" -f $proc.ProcessName, $procId) "Green"
        } catch {
            Say ("  PID {0} (no process info)" -f $procId) "Gray"
        }
    }
} else {
    Say "  No LISTENING entries on port 8000 yet." "Red"
}

# Optional: quick health probe
$healthUrlCandidates = @(
    "http://127.0.0.1:8000/api/health",
    "http://127.0.0.1:8000/api/ping"
)

foreach ($url in $healthUrlCandidates) {
    try {
        Say "`nTrying health probe: $url" "DarkGray"
        $res = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
        Say ("  -> HTTP {0}" -f $res.StatusCode) "Green"
        break
    } catch {
        Say ("  -> Failed: {0}" -f $_.Exception.Message) "DarkGray"
    }
}

Say "`n=== DONE: Ideally NIFDU HTTP is now on port 8000. Port 80 should be free for Caddy. ===`n" "Yellow"
