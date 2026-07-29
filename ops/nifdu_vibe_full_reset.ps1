# ==============================================
# C:\nifdu\ops\nifdu_vibe_full_reset.ps1
# HARD RESET FOR NIFDU VIBE STUDIO + KEY CHECK
# - Kills all nifdu.exe
# - Loads OpenAI key from C:\ENV\openai.key
# - Starts nifdu.exe
# - Tests /api/chat once
# ==============================================

$ErrorActionPreference = "Stop"

function Say {
    param([string]$m,[string]$c="Gray")
    try {
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$KeyFile = "C:\ENV\openai.key"
$ExePath = "C:\nifdu\build\Release\nifdu.exe"
$WorkDir = "C:\nifdu\build"

Say "`n=== NIFDU VIBE FULL RESET ===`n" "Yellow"

# 1) Load key
if (!(Test-Path $KeyFile)) {
    Say "[FATAL] Missing OpenAI key file: $KeyFile" "Red"
    exit 1
}

$key = (Get-Content $KeyFile -Raw).Trim()

if ($key -notmatch "^sk-") {
    Say "[FATAL] Invalid OpenAI key format in $KeyFile" "Red"
    exit 1
}

$env:OPENAI_API_KEY = $key
$env:NIFDU_BRAIN_PROVIDER = "openai"

$len = $key.Length
$tail = if ($len -gt 4) { $key.Substring($len - 4) } else { $key }
Say ("[1/4] OpenAI key loaded (length {0}, ends with ...{1})." -f $len, $tail) "Green"

# 2) Kill any existing nifdu.exe
Say "[2/4] Stopping any running nifdu.exe ..." "Cyan"
Get-Process -Name "nifdu" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Say "All existing nifdu.exe processes stopped (if any)." "Green"

# 3) Start nifdu.exe with this env
if (!(Test-Path $ExePath)) {
    Say "[FATAL] nifdu.exe not found at $ExePath" "Red"
    exit 1
}

Say "[3/4] Launching nifdu.exe from $WorkDir ..." "Cyan"
Start-Process -FilePath $ExePath -WorkingDirectory $WorkDir

Start-Sleep -Seconds 3

# 4) Smoke test /api/chat
Say "[4/4] Testing /api/chat with simple prompt ..." "Cyan"

$body = @{
  project = "vibe_studio_smoke"
  brain   = "auto"
  mode    = "vibe_coding"
  prompt  = "Return a single C++ hello world file."
} | ConvertTo-Json -Depth 5

try {
    $res = Invoke-WebRequest `
        -Uri "http://127.0.0.1/api/chat" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Say (" /api/chat StatusCode: {0}" -f $res.StatusCode) "Green"

    $json = $res.Content | ConvertFrom-Json
    Say (" Engine: {0}; Status: {1}; Model: {2}" -f $json.engine, $json.status, $json.model) "Green"

} catch {
    Say " /api/chat REQUEST FAILED" "Red"
    Say $_.Exception.Message "Red"
    if ($_.ErrorDetails) {
        Say $_.ErrorDetails.Message "Red"
    }
}
