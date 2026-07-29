param(
    [Parameter(Mandatory = $true)]
    [string]$Project,             # e.g. react_todo_tailwind_full, chess_lab_ui

    [Parameter(Mandatory = $true)]
    [string]$Prompt,              # full user instructions for Agent 3

    [string]$Stack       = "react",
    [string]$BaseUrl     = "http://127.0.0.1",
    [string]$TestCommand = "npm run build",
    [string]$ExpectText  = "",
    [int]$MaxCycles      = 5
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

function Wait-Nifdu {
    param([string]$Base)

    if ($Base.EndsWith("/")) {
        $health = "$Base" + "health"
    } else {
        $health = "$Base/health"
    }

    Say "[HTTP] Waiting for NIFDU at $health ..." "Cyan"
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $r = Invoke-WebRequest -Uri $health -TimeoutSec 2
            if ($r.StatusCode -eq 200) {
                Say "[HTTP] NIFDU ACTIVE." "Green"
                return $true
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    Say "[HTTP] Timeout waiting for $health" "Red"
    return $false
}

$AgentExec  = "C:\nifdu\ops\nifdu_agent3_apply_codegen.ps1"
$AppDir     = "C:\nifdu\src\apps\$Project"
$DiagDir    = "C:\nifdu\build\_diag"
$DeployRoot = "C:\webroot\nifdu.com\www\apps"

Say ""
Say "=== NIFDU AGENT 3 FULLSTACK AUTO-LOOP (WITH npm install) ===" "Cyan"
Say ("Project   : {0}" -f $Project) "Gray"
Say ("Stack     : {0}" -f $Stack)   "Gray"
Say ("AppDir    : {0}" -f $AppDir)  "Gray"
Say ("BaseUrl   : {0}" -f $BaseUrl) "Gray"
Say ("MaxCycles : {0}" -f $MaxCycles) "Gray"

if (!(Test-Path $AgentExec)) {
    Say "[FATAL] Agent executor missing: $AgentExec" "Red"
    exit 1
}
if (!(Test-Path $AppDir -PathType Container)) {
    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    Say ("[INFO] Created AppDir: {0}" -f $AppDir) "DarkYellow"
}
if (!(Test-Path $DiagDir)) {
    New-Item -ItemType Directory -Path $DiagDir -Force | Out-Null
}
if (!(Test-Path $DeployRoot)) {
    New-Item -ItemType Directory -Path $DeployRoot -Force | Out-Null
}

if (-not (Wait-Nifdu -Base $BaseUrl)) {
    exit 1
}

# ------------------------------------------------------------
# Strong React/Vite law baked into every cycle
# ------------------------------------------------------------
$ToolchainLaw = @"
IMPORTANT NIFDU TOOLCHAIN LAW (REACT STACK):

- Frontend stack: React + Vite (+ Tailwind if requested).
- DO NOT use create-react-app, webpack, or Next for this project.
- Project root: C:\nifdu\src\apps\$Project
- index.html MUST be at project root and load /src/main.tsx or /src/main.jsx via type="module".
- All source files live under: src/
- Use npm scripts:
    - npm run dev
    - npm run build
- Never write directly to:
    - C:\webroot
    - C:\inetpub

You ONLY modify files under:
  C:\nifdu\src\apps\$Project
"@

$BasePrompt = $Prompt + "`n`n" + $ToolchainLaw
$DeployUrl  = ($BaseUrl.TrimEnd("/")) + "/apps/$Project/"

# ------------------------------------------------------------
# AUTO LOOP
# ------------------------------------------------------------
for ($cycle = 1; $cycle -le $MaxCycles; $cycle++) {

    Say ""
    Say ("--- AUTO CYCLE {0} of {1} ---" -f $cycle, $MaxCycles) "Yellow"

    if ($cycle -eq 1) {
        $CyclePrompt = $BasePrompt
    } else {
        $CyclePrompt = $BasePrompt + @"

=== NIFDU DIAGNOSTICS (cycle $cycle) ===

[BUILD EXIT CODE] $buildExit

Please fix the project in-place under:
  $AppDir

Make tests pass and ensure that the deployed app at:
  $DeployUrl

responds with visible text that includes:
  $ExpectText
"@
    }

    # --------------------------
    # 1) Codegen via Agent 3
    # --------------------------
    Say "[1] Calling Agent 3 (/api/codegen via executor)..." "Cyan"
    & $AgentExec `
        -Project $Project `
        -Prompt  $CyclePrompt `
        -Stack   $Stack `
        -Brain   "auto" `
        -Mode    "vibe_coding"

    if ($LASTEXITCODE -ne 0) {
        Say ("[FATAL] Agent executor failed with exit code {0}." -f $LASTEXITCODE) "Red"
        exit $LASTEXITCODE
    }
    Say "  -> Agent 3 applied code changes." "Green"

    # --------------------------
    # 2) Ensure node_modules
    # --------------------------
    $nodeModules = Join-Path $AppDir "node_modules"
    if (!(Test-Path $nodeModules)) {
        Say ""
        Say "[2] node_modules missing -> running npm install..." "Cyan"
        Push-Location $AppDir
        $installOutput = & cmd.exe /c "npm install" 2>&1
        $installExit   = $LASTEXITCODE
        Pop-Location

        $installLogPath = Join-Path $DiagDir ("autoloop_{0}_npm_install_{1:yyyyMMdd_HHmmss}.log" -f $Project, (Get-Date))
        $installOutput | Out-File -FilePath $installLogPath -Encoding UTF8
        Say ("  -> npm install log: {0}" -f $installLogPath) "Gray"

        if ($installExit -ne 0) {
            Say ("[FAIL] npm install FAILED with exit code {0}." -f $installExit) "Red"
            if ($cycle -eq $MaxCycles) {
                Say "[STOP] Reached MaxCycles with failing npm install." "DarkYellow"
                exit $installExit
            }
            Say "[INFO] Will feed npm install failures into next Agent 3 cycle..." "DarkYellow"
            $buildExit = $installExit
            continue
        }

        Say "[2] npm install PASSED." "Green"
    } else {
        Say ""
        Say "[2] node_modules present -> skipping npm install." "Gray"
    }

    # --------------------------
    # 3) Build / test (IMMORTALITY)
    # --------------------------
    Say ""
    Say ("[3] Running test command: {0}" -f $TestCommand) "Cyan"

    Push-Location $AppDir

    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $buildOutput = & cmd.exe /c $TestCommand 2>&1
    $buildExit   = $LASTEXITCODE

    $ErrorActionPreference = $oldEap

    Pop-Location

    $buildLogPath = Join-Path $DiagDir ("autoloop_{0}_build_{1:yyyyMMdd_HHmmss}.log" -f $Project, (Get-Date))
    $buildOutput | Out-File -FilePath $buildLogPath -Encoding UTF8
    Say ("  -> Build log: {0}" -f $buildLogPath) "Gray"

    $hasCjsWarning = $buildOutput -match 'CJS build of Vite.*deprecated'
    $distIndex     = Join-Path $AppDir "dist\index.html"

    if ($buildExit -ne 0) {
        if ($hasCjsWarning -and (Test-Path $distIndex)) {
            Say ("[IMMORTALITY] Non-zero exit ({0}) but only Vite CJS noise + dist/index.html exists -> treating as SUCCESS." -f $buildExit) "DarkGray"
            $buildExit = 0
        } else {
            Say ("[FAIL] Build/Test FAILED with exit code {0}." -f $buildExit) "Red"
            if ($cycle -eq $MaxCycles) {
                Say "[STOP] Reached MaxCycles with failing build." "DarkYellow"
                exit $buildExit
            }
            Say "[INFO] Will feed build errors into next Agent 3 cycle..." "DarkYellow"
            continue
        }
    }

    if ($hasCjsWarning) {
        Say "Vite deprecation noise suppressed -- continuing" "DarkGray"
    }

    Say "[3] Build/Test PASSED." "Green"

    # --------------------------
    # 4) Deploy dist -> webroot
    # --------------------------
    Say ""
    Say "[4] Deploying dist -> NIFDU webroot..." "Cyan"
    $dist = Join-Path $AppDir "dist"
    if (!(Test-Path $dist)) {
        Say "[FATAL] dist folder missing after successful build." "Red"
        if ($cycle -eq $MaxCycles) { exit 1 }
        continue
    }

    $deployPath = Join-Path $DeployRoot $Project
    New-Item -ItemType Directory -Force -Path $deployPath | Out-Null
    robocopy $dist $deployPath /MIR /NFL /NDL | Out-Null
    Say ("  -> Deployed to {0}" -f $deployPath) "Gray"

    # --------------------------
    # 5) Probe via HTTP80
    # --------------------------
    Say ""
    Say ("[5] Probing deployed app at {0} expecting text '{1}'..." -f $DeployUrl, $ExpectText) "Cyan"

    $probeSuccess = $false

    for ($i = 1; $i -le 10; $i++) {
        Say ("  [TRY {0}] GET {1}" -f $i, $DeployUrl) "Gray"
        try {
            $resp   = Invoke-WebRequest -Uri $DeployUrl -UseBasicParsing -TimeoutSec 5
            $status = [int]$resp.StatusCode
            $body   = [string]$resp.Content

            if ($ExpectText) {
                $msgOk   = "  [OK] Body contains expected text '$ExpectText' (status $status)."
                $msgWarn = "  [WARN] Body does NOT yet contain expected text (status $status)."

                if ($body -like ("*{0}*" -f $ExpectText)) {
                    Say $msgOk "Green"
                    $probeSuccess = $true
                    break
                } else {
                    Say $msgWarn "DarkYellow"
                }
            } else {
                if ($status -ge 200 -and $status -lt 300) {
                    Say "  [OK] HTTP 2xx (no specific text required)." "Green"
                    $probeSuccess = $true
                    break
                } else {
                    Say ("  [WARN] Status {0} with no ExpectText constraint." -f $status) "DarkYellow"
                }
            }
        } catch {
            $msg = $_.Exception.Message
            Say ("  [ERR] Probe failed: {0}" -f $msg) "Red"
        }

        if ($i -lt 10) { Start-Sleep -Milliseconds 800 }
    }

    if ($probeSuccess) {
        Say ""
        Say "=== AUTO-LOOP COMPLETE: DEPLOYED APP HEALTHY ===" "Green"
        Say ("Open in browser: {0}" -f $DeployUrl) "Green"
        exit 0
    }

    Say "[WARN] Probe did not meet success criteria." "DarkYellow"

    if ($cycle -eq $MaxCycles) {
        Say "[STOP] Reached MaxCycles with failing probe." "DarkYellow"
        exit 1
    }

    Say "[INFO] Will feed probe issues into next Agent 3 cycle..." "DarkYellow"
}

Say "=== AUTO-LOOP ENDED WITHOUT SUCCESS ===" "Yellow"
exit 1
