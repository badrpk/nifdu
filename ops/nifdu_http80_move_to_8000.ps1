# ==============================================
# C:\nifdu\ops\nifdu_http80_move_to_8000.ps1
# Move nifdu::http80 server from port 80 -> 8000
# ----------------------------------------------
# - Edits start_server80() in nifdu_http_server80.cpp
# - Changes:
#     tcp::endpoint{tcp::v4(), 80}
#   to:
#     tcp::endpoint{tcp::v4(), 8000}
# - Also updates the log string "0.0.0.0:80" to "0.0.0.0:8000"
# - Stops nifdu.exe, rebuilds, restarts
# - Shows listeners on ports 80 and 8000
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

Say ""
Say "=== NIFDU http80 PORT MOVE (80 -> 8000) — FOCUSED PATCH ===" "Yellow"
Say ""

$HttpFile = "C:\nifdu\src\http\nifdu_http_server80.cpp"
$BuildDir = "C:\nifdu\build"
$ExePath  = "C:\nifdu\build\Release\nifdu.exe"

if (-not (Test-Path $HttpFile)) {
    Say "ERROR: HTTP server source not found at: $HttpFile" "Red"
    exit 1
}

# ----------------------------------------------
# 1) Backup file
# ----------------------------------------------
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup    = "$HttpFile.bak_http80_$timestamp"
Say ("Backing up {0} -> {1}" -f $HttpFile, $backup) "DarkGray"
Copy-Item $HttpFile $backup -Force

# ----------------------------------------------
# 2) Patch the acceptor + log line
# ----------------------------------------------
Say "Patching nifdu_http_server80.cpp..." "Cyan"

$content  = Get-Content $HttpFile -Raw
$original = $content
$changes  = 0

# Patch tcp::endpoint{tcp::v4(), 80}  ->  tcp::endpoint{tcp::v4(), 8000}
$new = $content -replace 'tcp::endpoint\{tcp::v4\(\),\s*80\}', 'tcp::endpoint{tcp::v4(), 8000}'
if ($new -ne $content) {
    $content = $new
    $changes++
    Say " - Updated acceptor endpoint to port 8000" "Green"
} else {
    Say " - No match for 'tcp::endpoint{tcp::v4(), 80}' (check file formatting)" "DarkGray"
}

# Also handle parentheses variant just in case:
$new = $content -replace 'tcp::endpoint\s*\(\s*tcp::v4\(\)\s*,\s*80\s*\)', 'tcp::endpoint(tcp::v4(), 8000)'
if ($new -ne $content) {
    $content = $new
    $changes++
    Say " - Updated acceptor endpoint (paren form) to port 8000" "Green"
}

# Patch the log line text: "0.0.0.0:80" -> "0.0.0.0:8000"
$new = $content -replace '0\.0\.0\.0:80', '0.0.0.0:8000'
if ($new -ne $content) {
    $content = $new
    $changes++
    Say " - Updated log string to 0.0.0.0:8000" "Green"
}

if ($changes -eq 0) {
    Say ""
    Say "WARNING: No changes applied. start_server80 may be formatted differently." "Yellow"
} else {
    Set-Content -Path $HttpFile -Value $content -Encoding UTF8
    Say ""
    Say ("Total changes applied: {0}. File updated." -f $changes) "Green"
}

# ----------------------------------------------
# 3) Stop existing nifdu.exe
# ----------------------------------------------
Say ""
Say "Stopping any running nifdu.exe..." "Cyan"
Get-Process -Name "nifdu" -ErrorAction SilentlyContinue | ForEach-Object {
    Say (" - Stopping PID {0}" -f $_.Id) "DarkGray"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# ----------------------------------------------
# 4) Rebuild (Release)
# ----------------------------------------------
if (-not (Test-Path $BuildDir)) {
    Say "ERROR: Build directory not found: $BuildDir" "Red"
    exit 1
}

Say ""
Say "Building NIFDU (Release)..." "Cyan"
Push-Location $BuildDir
cmake --build . --config Release
Pop-Location

# ----------------------------------------------
# 5) Restart nifdu.exe
# ----------------------------------------------
if (-not (Test-Path $ExePath)) {
    Say "ERROR: nifdu.exe not found at: $ExePath" "Red"
    exit 1
}

Say ""
Say ("Starting nifdu.exe from {0}..." -f $ExePath) "Cyan"
Start-Process $ExePath
Start-Sleep -Seconds 3

# ----------------------------------------------
# 6) Show listeners on 80 and 8000
# ----------------------------------------------
function Show-Port {
    param([int]$Port)
    Say ("Checking port {0} listeners..." -f $Port) "Cyan"
    $lines = netstat -ano | Select-String "LISTENING" | Select-String (":$Port ")
    if ($lines) {
        foreach ($l in $lines) {
            $parts  = $l.ToString().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
            $pid    = $parts[-1]
            try {
                $proc = Get-Process -Id $pid -ErrorAction Stop
                Say ("  {0} (PID {1})" -f $proc.ProcessName, $pid) "Green"
            } catch {
                Say ("  PID {0} (no process info)" -f $pid) "Gray"
            }
        }
    } else {
        Say ("  No LISTENING entries on port {0}" -f $Port) "DarkGray"
    }
}

Say ""
Show-Port -Port 80
Show-Port -Port 8000

Say ""
Say "=== DONE: http80 should now bind 8000 instead of 80. Port 80 should be free for Caddy. ===" "Yellow"
Say ""
