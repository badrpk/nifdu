param(
    [string]$Project = "todo_app_urdu",
    [string]$Prompt  = "Small Urdu todo app in C++ + HTML with full CRUD functionality",
    [string]$Mode    = "vibe_coding",
    [string]$Brain   = "auto"
)

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

$BuildDir = "C:\nifdu\build"
$ExePath  = "C:\nifdu\build\Release\nifdu.exe"
$AgentScript = "C:\nifdu\ops\nifdu_agent3_apply_codegen.ps1"

Say "`n=== NIFDU AGENT 3 FULL CYCLE (REBUILD + RESTART + CODEGEN) ===`n" "Yellow"

# 0) Kill old NIFDU
Say "[0] Killing any existing nifdu.exe..." "DarkYellow"
Get-Process nifdu -ErrorAction SilentlyContinue | Stop-Process -Force | Out-Null

# 1) Rebuild
Say "[1] Rebuilding NIFDU (Release)..." "Cyan"
Set-Location $BuildDir
cmake --build . --config Release

if (!(Test-Path $ExePath)) {
    Say "[FATAL] nifdu.exe not found at $ExePath" "Red"
    exit 1
}

# 2) Start fresh NIFDU
Say "[2] Starting fresh NIFDU.exe..." "Cyan"
Start-Process -FilePath $ExePath -WorkingDirectory $BuildDir

# 3) Wait for /health to be ready
$BaseUrl = "http://127.0.0.1"
$Health  = "$BaseUrl/health"

Say "[3] Waiting for $Health ..." "Cyan"
for ($i = 1; $i -le 40; $i++) {
    try {
        $h = Invoke-RestMethod -Uri $Health -Method Get -TimeoutSec 2
        if ($h.status -eq "ok") {
            Say "[OK] NIFDU is online (http80 health ok)." "Green"
            break
        }
    } catch {
        Start-Sleep -Milliseconds 500
    }
    if ($i -eq 40) {
        Say "[FATAL] /health did not become ready in time." "Red"
        exit 1
    }
}

# 4) Run Agent 3 codegen
Say "[4] Running Agent 3 codegen for project '$Project' ..." "Magenta"

& $AgentScript `
    -Project $Project `
    -Prompt  $Prompt `
    -Mode    $Mode `
    -Brain   $Brain
