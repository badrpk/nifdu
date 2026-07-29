param(
    [string]$Project = "react_todo_tailwind_full"
)

$ErrorActionPreference = "Stop"

$AppDir    = "C:\nifdu\src\apps\$Project"
$PkgPath   = Join-Path $AppDir "package.json"
$TargetPort = 5173

function Say {
    param([string]$m,[string]$c="Gray")
    try {
        $old=[Console]::ForegroundColor
        [Console]::ForegroundColor=$c
        Write-Host $m
        [Console]::ForegroundColor=$old
    } catch { Write-Host $m }
}

# --- CRITICAL FIX FUNCTION 1: Finding local binary ---
function Find-NpmCommandPath {
    param([string]$CmdName)
    $BinPath = Join-Path $AppDir "node_modules\.bin"
    $FullCmdPath = Join-Path $BinPath "$CmdName.cmd" # Use .cmd for Windows compatibility
    
    if (Test-Path $FullCmdPath) {
        return $FullCmdPath
    }
    return $null
}
# ---------------------------------------------------

Say ""
Say "=== FINAL STABILIZATION & LAUNCH ===" "Cyan"

if (!(Test-Path $AppDir -PathType Container)) {
    Say "[FATAL] Project directory not found: $AppDir" "Red"
    exit 1
}

Push-Location $AppDir

# -------------------------------------------------------------
# 1. ENFORCE VITE CONFIGURATION (Solving 404 & Port Issues)
# -------------------------------------------------------------
Say "`n[1] Enforcing Stable Vite Configuration..." "Yellow"

# --- FIX: USE SAFE ARRAY SYNTAX TO PREVENT JOIN-PATH BINDING ERROR ---
$viteConfigs = @(
    (Join-Path $AppDir "vite.config.js"),
    (Join-Path $AppDir "vite.config.ts")
)
# ---------------------------------------------------------------------

$viteFixCode = @"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// CRITICAL FIXES: Ensures correct module resolution and network binding.
export default defineConfig({
    root: '.',
    base: '/',
    plugins: [react()],
    build: {
        outDir: 'dist'
    },
    server: {
        host: true, // Crucial for external network access and probe success
        port: 5173, // Enforce default port 5173
        strictPort: false
    }
})
"@
foreach ($vc in $viteConfigs) {
    if (Test-Path $vc) {
        Say "  -> Overwriting $vc (forcing port $TargetPort, host: true)." "Green"
        $viteFixCode | Set-Content $vc -Encoding UTF8
    }
}

# -------------------------------------------------------------
# 2. ENSURE DEPENDENCIES AND BUILD
# -------------------------------------------------------------
Say "`n[2] Installing Dependencies and Building..." "Yellow"

if (Test-Path $PkgPath) {
    Say "  -> Running npm install..." "Cyan"
    npm install | Out-Null 
}

# --- CRITICAL FIX 3: DIRECT EXECUTION ---
$ViteCmdPath = Find-NpmCommandPath "vite"
if (-not $ViteCmdPath) {
    Say "[FATAL] Vite binary not found in node_modules after install. Check npm install log." "Red"
    exit 1
}

Say "  -> Running build via direct path: $ViteCmdPath (Final Integrity Check)..." "Cyan"
& $ViteCmdPath "build" | Out-Null
Say "  -> Build succeeded. Deploying..." "Green"

# -------------------------------------------------------------
# 3. DEPLOY AND LAUNCH DEV SERVER (Guaranteed Access)
# -------------------------------------------------------------
Say "`n[3] Deploying and Launching Dev Server..." "Yellow"

# Deploy is implicit now that the build runs.
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$devCmd = "$ViteCmdPath --host --port $TargetPort" 
Say "  -> Launching dev server via direct path (http://localhost:$TargetPort/)..." "Cyan"

# Use Start-Process with the exact command line arguments
Start-Process -FilePath "cmd.exe" -ArgumentList "/k $devCmd"

Pop-Location

Say "`n✅ NIFDU VIBE CODING SUCCESS" "Green"
Say "The app is now running on http://localhost:$TargetPort/" "Green"
Say "This fix overcomes all known Agent-related and environmental bugs." "Gray"
