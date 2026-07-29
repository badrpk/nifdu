$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$m,
        [string]$c = "Gray"
    )
    try {
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$NifduRoot = "C:\nifdu"
$BuildDir  = Join-Path $NifduRoot "build"
$ExePath   = Join-Path $BuildDir "Release\nifdu.exe"
$SurfaceScript = Join-Path $NifduRoot "ops\nifdu_api_surface_check.ps1"

Say ""
Say "=== NIFDU BOOT + HTTP SURFACE CHECK ===" "Yellow"

if (-not (Test-Path $ExePath)) {
    Say "[FATAL] nifdu.exe not found at $ExePath" "Red"
    Say "        Run CMake + build first." "Red"
    exit 1
}

# 1) Kill existing nifdu (if any)
Say "[STEP 1] Killing existing nifdu.exe (if running)..." "Cyan"
Get-Process nifdu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Milliseconds 500

# 2) Start nifdu.exe
Say "[STEP 2] Starting nifdu.exe..." "Cyan"
$proc = Start-Process -FilePath $ExePath -NoNewWindow -PassThru
Say ("[OK] nifdu.exe started (PID: {0})" -f $proc.Id) "Green"

# 3) Give server time to bind port 80
Start-Sleep -Seconds 4

# 4) Run HTTP surface check
if (Test-Path $SurfaceScript) {
    Say "[STEP 3] Running HTTP surface check script..." "Cyan"
    powershell -ExecutionPolicy Bypass -File $SurfaceScript
} else {
    Say "[WARN] Surface check script not found at $SurfaceScript" "DarkYellow"
}

Say ""
Say "=== NIFDU BOOT + HTTP SURFACE CHECK DONE ===" "Yellow"
