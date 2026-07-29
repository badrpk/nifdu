$ErrorActionPreference = "Stop"

function Say {
    param([string]$m, [string]$c = "Gray")
    try { $old = [Console]::ForegroundColor; [Console]::ForegroundColor = $c; Write-Host $m; [Console]::ForegroundColor = $old }
    catch { Write-Host $m }
}

$DotEnvPath = "C:\ENV\.env"

function Load-DotEnv {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw ".env not found at $Path. Make sure C:\ENV\.env exists."
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^\s*#') { return }
        if ($_ -match '^\s*$') { return }

        if ($_ -match '^\s*([^=]+)=(.*)$') {
            $name  = $matches[1].Trim()
            $value = $matches[2].Trim()

            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            # Set environment variable for THIS PROCESS (and children)
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

Say "`n=== NIFDU MONOLITH LAUNCHER (WITH C:\ENV\.env) ===`n" "Yellow"

Load-DotEnv -Path $DotEnvPath

if (-not [string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "Process"))) {
    Say "[OK] OPENAI_API_KEY is set in process environment." "Green"
} else {
    Say "[FATAL] OPENAI_API_KEY is NOT set after loading .env. Check C:\ENV\.env" "Red"
    exit 1
}

$ExePath = "C:\nifdu\build\Release\nifdu.exe"

Say "[STEP] Killing any existing nifdu.exe..." "Cyan"
Get-Process nifdu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Say "[STEP] Starting nifdu.exe --port 80 with injected environment..." "Cyan"
Set-Location "C:\nifdu\build"

# Run in foreground so it keeps env; press Ctrl+C to stop when needed
.\Release\nifdu.exe --port 80
