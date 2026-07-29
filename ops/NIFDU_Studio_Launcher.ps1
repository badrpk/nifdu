param()

\Stop = "Stop"

function Say {
    param([string]\,[string]\="Gray")
    \=[Console]::ForegroundColor
    if ([enum]::GetNames([ConsoleColor]) -contains \) {
        [Console]::ForegroundColor=\
    }
    Write-Host \
    [Console]::ForegroundColor=\
}

\C:\nifdu = "C:\nifdu"
\C:\nifdu\build    = "C:\nifdu\build"
\C:\nifdu\build\Release\nifdu.exe     = "C:\nifdu\build\Release\nifdu.exe"

\http://127.0.0.1/    = "http://127.0.0.1/"
\http://127.0.0.1/agent3/start.html   = "http://127.0.0.1/agent3/start.html"
\http://127.0.0.1/apps/agent3_preview/index.html?project=make_snake_game = "http://127.0.0.1/apps/agent3_preview/index.html?project=make_snake_game"

function Get-NifduProcess {
    Get-Process nifdu -ErrorAction SilentlyContinue
}

function Start-Nifdu {
    if (Get-NifduProcess) {
        Say "[INFO] nifdu.exe already running." "DarkYellow"
        return
    }
    if (-not (Test-Path \C:\nifdu\build\Release\nifdu.exe)) {
        Say "FATAL: nifdu.exe not found at \C:\nifdu\build\Release\nifdu.exe" "Red"
        return
    }
    Say "[ACTION] Starting nifdu.exe..." "Cyan"
    Start-Process -FilePath \C:\nifdu\build\Release\nifdu.exe -WindowStyle Hidden
    Start-Sleep -Seconds 3
    if (Get-NifduProcess) {
        Say "[OK] nifdu.exe started." "Green"
    } else {
        Say "[WARN] nifdu.exe did not appear in process list." "Red"
    }
}

function Stop-Nifdu {
    \ = Get-NifduProcess
    if (-not \) {
        Say "[INFO] nifdu.exe not running." "DarkYellow"
        return
    }
    Say "[ACTION] Stopping nifdu.exe..." "Cyan"
    \ | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-NifduProcess)) {
        Say "[OK] nifdu.exe stopped." "Green"
    } else {
        Say "[WARN] Could not fully stop nifdu.exe." "Red"
    }
}

function Show-Status {
    \ = Get-NifduProcess
    if (\) {
        Say ("[STATUS] nifdu.exe is running (PID " + \.Id + ")") "Green"
    } else {
        Say "[STATUS] nifdu.exe is NOT running." "Red"
    }
    try {
        \{"status":"ok","stub":true,"endpoint":"/api/health","method":"GET","engine":"nifdu_http80_stub"} = Invoke-WebRequest -Uri "http://127.0.0.1/health" -UseBasicParsing -TimeoutSec 2
        Say ("[HEALTH] /health -> HTTP " + \{"status":"ok","stub":true,"endpoint":"/api/health","method":"GET","engine":"nifdu_http80_stub"}.StatusCode) "Green"
    } catch {
        Say "[HEALTH] /health not reachable." "DarkYellow"
    }
}

function Open-Url([string]\,[string]\) {
    Say ("[ACTION] Opening " + \ + " -> " + \) "Cyan"
    Start-Process \
}

# Simple main menu loop
while (\True) {
    Clear-Host
    Say "=== NIFDU STUDIO ===" "Yellow"
    Write-Host ""
    Show-Status
    Write-Host ""
    Write-Host "  1) Start NIFDU server"
    Write-Host "  2) Stop NIFDU server"
    Write-Host "  3) Open NIFDU home portal (http://127.0.0.1/)"
    Write-Host "  4) Open Agent 3 live session (http://127.0.0.1/agent3/start.html)"
    Write-Host "  5) Open Agent 3 preview surface (http://127.0.0.1/apps/agent3_preview/index.html?project=make_snake_game)"
    Write-Host "  6) Exit"
    Write-Host ""
    \ = Read-Host "Select option"

    switch (\) {
        "1" { Start-Nifdu; Start-Sleep 1 }
        "2" { Stop-Nifdu;  Start-Sleep 1 }
        "3" { Start-Nifdu; Open-Url \http://127.0.0.1/ "home portal";   Start-Sleep 1 }
        "4" { Start-Nifdu; Open-Url \http://127.0.0.1/agent3/start.html "Agent 3";      Start-Sleep 1 }
        "5" { Start-Nifdu; Open-Url \http://127.0.0.1/apps/agent3_preview/index.html?project=make_snake_game "preview UI"; Start-Sleep 1 }
        "6" { break }
        default { Say "[INFO] Invalid choice. Use 1-6." "DarkYellow"; Start-Sleep 1 }
    }
}

Say "
Exiting NIFDU Studio..." "Yellow"
