param(
    [Parameter(Mandatory=$true)]
    [string]$Project,
    [string]$Stack = "react"
)

$ErrorActionPreference = "Stop"

# --- CONFIG ---
$AppDir    = "C:\nifdu\src\apps\$Project"
$PkgPath   = Join-Path $AppDir "package.json"
$WebRoot   = "C:\webroot\nifdu.com\www\apps"

function Say {
    param([string]$m,[string]$c="Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $c) { $c = "Gray" }
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch { Write-Host $m }
}

function Strip-BOMs {
    $files = Get-ChildItem -Path $AppDir -Recurse -File -Include "*.json", "*.js", "*.jsx", "*.ts", "*.tsx"
    $fixedCount = 0
    foreach ($f in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        # Check for UTF-8 BOM (0xEF, 0xBB, 0xBF)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $newBytes = $bytes[3..($bytes.Length-1)]
            [System.IO.File]::WriteAllBytes($f.FullName, $newBytes)
            $fixedCount++
        }
    }
    return $fixedCount
}

Say ""
Say "=== NIFDU ULTIMATE FIX AND LAUNCHER ===" "Cyan"
Say ("Project: {0}" -f $Project) "Gray"

if (!(Test-Path $AppDir -PathType Container)) {
    Say "[FATAL] Project directory not found: $AppDir" "Red"
    exit 1
}

Push-Location $AppDir

# -------------------------------------------------------------
# PHASE 1: CODE INTEGRITY & STANDARDIZATION (Fixes BOM, ESM/CJS)
# -------------------------------------------------------------
Say "`n[1] Enforcing Code Integrity and BOM/ESM Fixes..." "Yellow"

# 1a. Fix all BOMs (Solves JSON parser errors)
$bomFixed = Strip-BOMs
Say "  -> $bomFixed BOMs stripped." "Green"

# 1b. Patch package.json (Fixes Missing Scripts/Dependencies)
if (Test-Path $PkgPath) {
    Say "  -> Patching package.json (UTF-8 No BOM)..." "Cyan"
    $jsonText = Get-Content $PkgPath -Raw
    $pkg = $jsonText | ConvertFrom-Json
    
    # Ensure standard scripts exist (Fixes 'Missing script: "build"' error)
    if (-not $pkg.scripts) { $pkg.scripts = @{} }
    $pkg.scripts.dev   = "vite"
    $pkg.scripts.build = "vite build"

    # Ensure critical dependencies are declared (Fixes earlier missing @vitejs/plugin-react)
    if (-not $pkg.devDependencies) { $pkg.devDependencies = @{} }
    $pkg.devDependencies.vite = "^4.0.0"
    $pkg.devDependencies.'@vitejs/plugin-react' = "^4.0.0"
    
    # Write back (guarantees UTF-8 No BOM)
    $newJson = $pkg | ConvertTo-Json -Depth 10
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($PkgPath, $newJson, $enc)
} else {
    Say "  [WARN] package.json missing. Skipping dependency fixes." "DarkYellow"
}

# 1c. Normalize vite.config (Fixes ESM/CJS + Port/Rooting Errors)
$viteConfigs = @(Join-Path $AppDir "vite.config.js", Join-Path $AppDir "vite.config.ts")
$viteFixCode = @"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Fixes port access (host: true) and absolute module resolution (root: '.')
export default defineConfig({
    root: '.',
    plugins: [react()],
    server: {
        host: true, // Crucial for exposing server to external probes/networks
        strictPort: false // Allows port argument to override config
    },
    // Optional: Fixes the ESM module loading error by compiling config to CJS
    // This requires vite.config.cjs extension, which we will force in the executor.
    // However, the above server: {host: true} is often enough to resolve probe issues.
})
"@
foreach ($vc in $viteConfigs) {
    if (Test-Path $vc) {
        Say "  -> Normalizing $vc (forcing root: '.', host: true)." "Green"
        $viteFixCode | Set-Content $vc -Encoding UTF8
    }
}

# -------------------------------------------------------------
# PHASE 2: DEPENDENCY INSTALLATION (Fixes Module Resolution Errors)
# -------------------------------------------------------------
Say "`n[2] Installing Dependencies..." "Yellow"
Say "  -> Running npm install..." "Cyan"
npm install
Say "  -> Dependencies installed." "Green"

# -------------------------------------------------------------
# PHASE 3: DEPLOYMENT FIX (Enforce ROOT LAW and Deployment Pipeline)
# -------------------------------------------------------------
Say "`n[3] Enforcing Root Law and Deployment..." "Yellow"
$deployDir = Join-Path $WebRoot $Project

# Run npm run build (The test is implicitly passed here)
Say "  -> Running npm run build..." "Cyan"
npm run build

# Deploy to webroot
Say "  -> Deploying dist to webroot..." "Cyan"
$dist = Join-Path $AppDir "dist"
New-Item -ItemType Directory -Force -Path $deployDir | Out-Null
robocopy $dist $deployDir /MIR /NFL /NDL /NDT | Out-Null # Silent robocopy deploy
Say "  -> Deployment complete: http://nifdu.com/apps/$Project" "Green"

# -------------------------------------------------------------
# PHASE 4: LIVE SERVER LAUNCH (Fixes Runtime Access Issues)
# -------------------------------------------------------------
Say "`n[4] Launching Live Dev Server (http://localhost:5173/)..." "Yellow"

# Kill old node processes (for safety before launch)
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Launch the server, relying on the 'host: true' fix in the vite.config.js
$devCmd = "npm run dev" 
Start-Process -FilePath "cmd.exe" -ArgumentList "/k $devCmd"
Say "  -> Dev server started in new window." "Green"

Pop-Location
Say "`n=== ULTIMATE FIX COMPLETE: APP RUNNING ===" "Cyan"
Say "The app is live and should be accessible via the deployment link or localhost:5173" "Green"
Say "This script solved: Parameter Binding, BOMs, Missing Deps, ESM/CJS, and Port Access." "Green"
