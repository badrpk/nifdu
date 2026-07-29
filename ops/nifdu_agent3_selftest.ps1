param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [Parameter(Mandatory=$true)]
    [string]$TestCommand,

    [int]$MaxCycles = 5,

    [string]$Stack = "auto",
    [string]$Brain = "auto",
    [string]$Mode  = "vibe_coding"
)

$ErrorActionPreference = "Stop"

$AgentExec = "C:\nifdu\ops\nifdu_agent3_apply_codegen.ps1"
$AppDir    = "C:\nifdu\src\apps\$Project"
$DiagDir   = "C:\nifdu\build\_diag"

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

if (!(Test-Path $AgentExec)) {
    Say "[FATAL] Agent executor missing: $AgentExec" "Red"
    exit 1
}
if (!(Test-Path $AppDir -PathType Container)) {
    Say "[FATAL] AppDir not found: $AppDir" "Red"
    exit 1
}
if (!(Test-Path $DiagDir)) {
    New-Item -ItemType Directory -Path $DiagDir -Force | Out-Null
}

Say ""
Say "=== NIFDU AGENT 3 SELF-TEST LOOP ===" "Cyan"
Say ("Project     : {0}" -f $Project) "Gray"
Say ("AppDir      : {0}" -f $AppDir)  "Gray"
Say ("TestCommand : {0}" -f $TestCommand) "Gray"
Say ("MaxCycles   : {0}" -f $MaxCycles) "Gray"

if (-not (Wait-Nifdu)) {
    exit 1
}

for ($cycle = 1; $cycle -le $MaxCycles; $cycle++) {
    Say ""
    Say ("--- TEST CYCLE {0} of {1} ---" -f $cycle, $MaxCycles) "Yellow"

    Push-Location $AppDir
    Say ("[TEST] Running: {0}" -f $TestCommand) "Cyan"

    $testOutput = & cmd.exe /c $TestCommand 2>&1
    $exitCode   = $LASTEXITCODE
    Pop-Location

    $logName = Join-Path $DiagDir ("selftest_{0}_{1:yyyyMMdd_HHmmss}.log" -f $Project, (Get-Date))
    $testOutput | Out-File -FilePath $logName -Encoding UTF8
    Say ("[LOG] Test output written to: {0}" -f $logName) "Gray"

    if ($exitCode -eq 0) {
        Say "[OK] Tests PASSED." "Green"
        Say "=== SELF-TEST LOOP COMPLETE (SUCCESS) ===" "Yellow"
        exit 0
    }

    Say ("[FAIL] Tests FAILED with exit code {0}." -f $exitCode) "Red"

    if ($cycle -ge $MaxCycles) {
        Say "[STOP] Reached MaxCycles. Leaving failing test results for manual inspection." "DarkYellow"
        exit $exitCode
    }

    # Prepare a shortened error snippet for the agent
    $snippet = $testOutput | Select-Object -Last 80
    $snippetText = ($snippet -join [Environment]::NewLine)

    $FixPrompt = @"
You are NIFDU Agent 3, fixing an existing project.

PROJECT:
  Name : $Project
  Path : $AppDir

GOAL:
  Make this test command succeed without errors:

  $TestCommand

CONTEXT:
  - The project already exists. Do NOT create a new root folder.
  - Only modify files under: $AppDir
  - Keep paths stable so NIFDU scripts and dev server continue to work.
  - Prefer minimal, targeted fixes instead of rewrites.

LATEST FAILING TEST OUTPUT (truncated tail):
$snippetText

TASK:
  - Analyze the error output.
  - Edit the existing files to fix the underlying issues.
  - Return an updated file set using the same paths.
"@

    Say "[FIX] Asking Agent 3 to repair project based on failing tests..." "Cyan"

    & $AgentExec `
        -Project $Project `
        -Prompt  $FixPrompt `
        -Stack   $Stack `
        -Brain   $Brain `
        -Mode    $Mode

    if ($LASTEXITCODE -ne 0) {
        Say ("[FATAL] Agent executor failed with exit code {0}." -f $LASTEXITCODE) "Red"
        exit $LASTEXITCODE
    }

    Say "[FIX] Agent 3 applied code changes. Re-running tests next cycle..." "Green"
}

Say "=== SELF-TEST LOOP COMPLETE (NO SUCCESS) ===" "Yellow"
exit 1
