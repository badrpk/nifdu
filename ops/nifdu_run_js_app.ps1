param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [string]$Stack = "auto"   # react | next | vue | angular | node | auto
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$m,[string]$c="Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $c) { $c = "Gray" }
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$AppDir = "C:\nifdu\src\apps\$Project"
$Pkg    = Join-Path $AppDir "package.json"

Say ""
Say "=== NIFDU JS APP RUNNER ===" "Cyan"
Say "Project  = $Project" "Gray"
Say "Stack    = $Stack"   "Gray"
Say "AppDir   = $AppDir"  "Gray"

if (!(Test-Path $AppDir)) {
    Say "[FATAL] App directory not found: $AppDir" "Red"
    exit 1
}
if (!(Test-Path $Pkg)) {
    Say "[FATAL] package.json not found in $AppDir" "Red"
    exit 1
}

Push-Location $AppDir

Say "[1] Reading package.json ..." "Cyan"
$pkgJson = Get-Content $Pkg -Raw | ConvertFrom-Json
$scripts = $pkgJson.scripts

if (-not $scripts) {
    Say "[FATAL] No scripts section in package.json" "Red"
    Pop-Location
    exit 1
}

# Decide which script to run
$scriptName = $null

if ($Stack -eq "node") {
    if ($scripts.start) { $scriptName = "start" }
    elseif ($scripts.dev) { $scriptName = "dev" }
} else {
    if ($scripts.dev) { $scriptName = "dev" }
    elseif ($scripts.start) { $scriptName = "start" }
}

if (-not $scriptName) {
    Say "[FATAL] Could not decide script to run (no dev/start found)." "Red"
    Pop-Location
    exit 1
}

Say "[2] Running npm install (once) ..." "Cyan"
npm install

# Vite + React auto-fix: ensure CJS-friendly versions
$viteConfig = Join-Path $AppDir "vite.config.js"
if (Test-Path $viteConfig) {
    Say "[2b] Detected vite.config.js - ensuring vite + @vitejs/plugin-react are compatible..." "Cyan"

    $needFix = $true

    if ($pkgJson.devDependencies) {
        if ($pkgJson.devDependencies.vite -and $pkgJson.devDependencies.'@vitejs/plugin-react') {
            $needFix = $false
            Say " -> vite and @vitejs/plugin-react already listed in devDependencies." "Gray"
        }
    }

    if ($needFix) {
        Say " -> Installing vite@4.5.0 and @vitejs/plugin-react@4.0.0 (CJS-friendly)..." "Green"
        npm install -D "vite@4.5.0" "@vitejs/plugin-react@4.0.0"
    }
}

Say ("[3] Running npm run {0} (Ctrl+C to stop) ..." -f $scriptName) "Cyan"
npm run $scriptName

Pop-Location
