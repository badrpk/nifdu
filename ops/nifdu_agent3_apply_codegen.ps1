param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [string]$Stack = "auto",   # react / next / vue / angular / node / cpp / auto
    [string]$Brain = "auto",
    [string]$Mode  = "vibe_coding",

    [string]$LogDir    = "C:\nifdu\build\_diag",
    [string]$ExePath   = "C:\nifdu\build\Release\nifdu.exe",
    [string]$CodegenUrl = "http://127.0.0.1/api/codegen"
)

$ErrorActionPreference = "Stop"

# Use a local variable instead of a parameter to avoid binding issues
$MaxRetries = 3

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

function Wait-Nifdu {
    Say "[HTTP] Waiting for NIFDU on port 80..."
    for ($i=0; $i -lt 40; $i++) {
        try {
            $v = Invoke-WebRequest -Uri "http://127.0.0.1/health" -TimeoutSec 2
            if ($v.StatusCode -eq 200) {
                Say "[HTTP] NIFDU ACTIVE." "Green"
                return $true
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    Say "[HTTP] Timeout waiting for 127.0.0.1/health" "Red"
    return $false
}

Say ""
Say "=== NIFDU AGENT 3 MULTI-STACK EXECUTOR ===" "Cyan"
Say ("Project : {0}" -f $Project) "Gray"
Say ("Stack   : {0}" -f $Stack)   "Gray"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

for ($Attempt = 1; $Attempt -le $MaxRetries; $Attempt++) {

    Say ""
    Say ("--- Attempt {0} of {1} ---" -f $Attempt, $MaxRetries) "Yellow"

    # Kill any existing nifdu.exe and restart
    Stop-Process -Name "nifdu" -ErrorAction SilentlyContinue | Out-Null
    Start-Process -FilePath $ExePath -WindowStyle Hidden | Out-Null

    if (-not (Wait-Nifdu)) {
        exit 1
    }

    # Body sent to /api/codegen
    $Body = @{
        project = $Project
        prompt  = @"
SYSTEM OVERRIDE — NIFDU AGENT 3 MULTI-STACK

User prefers modern UI frameworks unless C++ is explicitly required.

Allowed stacks:
- react
- next
- vue
- angular
- node
- html
- cpp (only when user insists)

Stack selected for this request: $Stack

USER PROMPT:
$Prompt
"@

        brain   = $Brain
        mode    = $Mode
        stack   = $Stack
    }

    $Json = $Body | ConvertTo-Json -Depth 12

    Say "[1] Calling /api/codegen..." "Cyan"
    try {
        $Resp = Invoke-RestMethod -Uri $CodegenUrl -Method Post -Body $Json `
            -ContentType "application/json; charset=utf-8"
    } catch {
        Say ("[FATAL] API FAILED: {0}" -f $_.Exception.Message) "Red"
        if ($Attempt -lt $MaxRetries) {
            Say "[INFO] Retrying..." "DarkYellow"
            continue
        }
        exit 1
    }

    if ($Resp.status -ne "ok") {
        Say "[FATAL] Codegen returned ERROR" "Red"
        if ($Resp.error) {
            Say ("  -> {0}" -f $Resp.error) "Red"
        }
        exit 1
    }

    Say ("[OK] Codegen success (engine={0})" -f $Resp.engine) "Green"

    foreach ($f in $Resp.files) {
        $d = Split-Path $f.path -Parent
        if (!(Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
        $f.content | Out-File -FilePath $f.path -Encoding UTF8
        Say ("  -> {0}" -f $f.path) "Gray"
    }

    Say ""
    Say "=== SUCCESS ===" "Yellow"
    exit 0
}

Say "[FAILED] All retries exhausted." "Red"
exit 1
