param(
    [Parameter(Mandatory=$true)]
    [string]$Project
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
    } catch { Write-Host $m }
}

$AppDir = "C:\nifdu\src\apps\$Project"
$Pkg    = Join-Path $AppDir "package.json"

Say "`n=== NIFDU VITE/REACT FIXER & RUNNER ===`n" "Cyan"

if (!(Test-Path $AppDir -PathType Container) -or !(Test-Path $Pkg)) {
    Say "[FATAL] Project setup incomplete or package.json missing." "Red"
    exit 1
}

Push-Location $AppDir

# 1. Auto-install missing @vitejs/plugin-react
Say "[1] Auto-installing @vitejs/plugin-react..." "Cyan"
npm install -D @vitejs/plugin-react

# 2. Re-install all dependencies (just in case)
Say "[2] Running npm install..." "Cyan"
npm install

# 3. Start dev server (npm run dev should be defined by the Agent)
Say "[3] Running npm run dev (Ctrl+C to stop)..." "Cyan"
npm run dev

Pop-Location
