# ==============================================
# C:\nifdu\ops\nifdu_boot_with_env.ps1
# Load OpenAI key from C:\ENV\openai.key and start NIFDU
# ==============================================

$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )

    try {
        $oldColor = [Console]::ForegroundColor
        [Console]::ForegroundColor = $Color
        Write-Host $Message
        [Console]::ForegroundColor = $oldColor
    }
    catch {
        Write-Host $Message
    }
}

# Paths
$KeyFile = "C:\ENV\openai.key"
$ExePath = "C:\nifdu\build\Release\nifdu.exe"
$WorkDir = "C:\nifdu\build"

Say ""
Say "=== NIFDU BOOT : LOAD OPENAI KEY FROM FILE ===" "Yellow"
Say ""

# ----------------------------------------------
# 1) Load OpenAI key from file
# ----------------------------------------------
if (!(Test-Path $KeyFile)) {
    Say "FATAL: OpenAI key file not found at: $KeyFile" "Red"
    exit 1
}

$keyRaw = Get-Content -Path $KeyFile -Raw
$OpenAIKey = $keyRaw.Trim()

if ([string]::IsNullOrWhiteSpace($OpenAIKey)) {
    Say "FATAL: OpenAI key file is empty." "Red"
    exit 1
}

if (-not $OpenAIKey.StartsWith("sk-")) {
    Say "FATAL: OpenAI key does not look valid (does not start with 'sk-')." "Red"
    exit 1
}

# Set environment variables for this PowerShell session and child processes
Set-Item -Path Env:OPENAI_API_KEY        -Value $OpenAIKey
Set-Item -Path Env:NIFDU_BRAIN_PROVIDER  -Value "auto"
Set-Item -Path Env:NIFDU_OPENAI_MODEL    -Value "gpt-4.1-mini"
Set-Item -Path Env:NIFDU_OPENAI_INSECURE -Value "1"

Say "[1/3] OpenAI key loaded from C:\ENV\openai.key and environment variables set." "Green"

# ----------------------------------------------
# 2) Stop existing nifdu.exe if running
# ----------------------------------------------
Say "[2/3] Stopping existing nifdu.exe (if any)..." "Cyan"

try {
    $existing = Get-Process -Name "nifdu" -ErrorAction SilentlyContinue
    if ($existing) {
        $existing | Stop-Process -Force -ErrorAction SilentlyContinue
        Say "Existing nifdu.exe process stopped." "Green"
    }
    else {
        Say "No existing nifdu.exe process found." "DarkGray"
    }
}
catch {
    Say "Warning: could not stop existing nifdu.exe (continuing anyway)." "Yellow"
}

# ----------------------------------------------
# 3) Start nifdu.exe with env applied
# ----------------------------------------------
if (!(Test-Path $ExePath)) {
    Say "FATAL: nifdu.exe not found at: $ExePath" "Red"
    exit 1
}

Say "[3/3] Launching nifdu.exe from $WorkDir ..." "Cyan"

Push-Location $WorkDir
try {
    Start-Process -FilePath $ExePath -WorkingDirectory $WorkDir
    Say "nifdu.exe launched successfully with OpenAI key applied." "Green"
}
finally {
    Pop-Location
}
