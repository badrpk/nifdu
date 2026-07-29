param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptName,      # e.g. nifdu_my_auto_backup.ps1

    [Parameter(Mandatory=$true)]
    [string]$Instruction,     # natural language spec for this automation

    [string]$Brain = "auto",
    [string]$Mode  = "vibe_coding"
)

$ErrorActionPreference = "Stop"

$OpsDir    = "C:\nifdu\ops"
$AgentExec = "C:\nifdu\ops\nifdu_agent3_apply_codegen.ps1"
$Project   = "ops_" + ($ScriptName -replace '\.ps1$','')
$Target    = Join-Path $OpsDir $ScriptName

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

function Wait-Nifdu {
    Say "[HTTP] Waiting for NIFDU on port 80..." "Cyan"
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

if (!(Test-Path $OpsDir)) {
    New-Item -ItemType Directory -Path $OpsDir -Force | Out-Null
}
if (!(Test-Path $AgentExec)) {
    Say "[FATAL] Agent executor missing: $AgentExec" "Red"
    exit 1
}

Say ""
Say "=== NIFDU AGENT 3 - OPS AGENT FACTORY ===" "Cyan"
Say ("ScriptName : {0}" -f $ScriptName) "Gray"
Say ("Project    : {0}" -f $Project)    "Gray"
Say ("Target     : {0}" -f $Target)     "Gray"

if (-not (Wait-Nifdu)) {
    exit 1
}

$Prompt = @"
You are NIFDU Agent 3, generating a new PowerShell automation script that will live in:

  $Target

GOAL:
  - Implement the following automation/agent behavior in a single PowerShell script:
  - The script will be run directly by the user (no extra setup).

USER INSTRUCTION (HIGH LEVEL SPEC):
$Instruction

REQUIREMENTS:
  - Output exactly one file at path: $Target
  - The script must be self-contained PowerShell (no Python, no Node).
  - Use the "Say" helper style for colored console output if helpful.
  - Prefer clear logging and safe behavior over destructive actions.
  - Do NOT delete databases or production data.
  - Assume it will run on Windows with PowerShell 5+.

RETURN:
  - A single file definition that writes the full script to $Target.
"@

& $AgentExec `
    -Project $Project `
    -Prompt  $Prompt `
    -Stack   "cpp" `
    -Brain   $Brain `
    -Mode    $Mode

if ($LASTEXITCODE -ne 0) {
    Say ("[FATAL] Agent executor failed with exit code {0}." -f $LASTEXITCODE) "Red"
    exit $LASTEXITCODE
}

if (Test-Path $Target) {
    Say ("[OK] New ops agent created at {0}" -f $Target) "Green"
} else {
    Say "[WARN] Agent executor ran, but target script not found. Check /api/codegen output." "DarkYellow"
}

Say "=== OPS AGENT FACTORY COMPLETE ===" "Yellow"
