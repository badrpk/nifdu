param(
    [string]$Project      = "todo_app_urdu",
    [string]$Prompt       = "Small Urdu todo app in C++ + HTML, with Urdu labels and keyboard shortcuts.",
    [int]   $MaxFixLoops  = 3,
    [string]$BaseUrl      = "http://127.0.0.1",
    [string]$BuildDir     = "C:\nifdu\build"
)

$ErrorActionPreference = "Stop"

# -------------------------------
# Pretty logger
# -------------------------------
function Say {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $Color
        Write-Host $Message
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $Message
    }
}

Say "`n=== NIFDU APP WRITER v2 — Agent 3 Style (Project: $Project) ===`n" "Yellow"

# -------------------------------
# Endpoints + paths
# -------------------------------
$CodegenUrl = "$BaseUrl/api/codegen"
$ChatUrl    = "$BaseUrl/api/chat"

$DiagDir = "C:\nifdu\_diag"
if (!(Test-Path $DiagDir)) {
    New-Item -ItemType Directory -Path $DiagDir -Force | Out-Null
}
$BuildLog = Join-Path $DiagDir ("build_{0}.log" -f $Project)

# -------------------------------
# Helpers
# -------------------------------
function Invoke-NifduJsonPost {
    param(
        [string]$Url,
        [hashtable]$Body
    )

    $json = ($Body | ConvertTo-Json -Depth 10)
    Say "`n[HTTP] POST $Url" "DarkCyan"
    Say $json "DarkGray"

    try {
        $resp = Invoke-RestMethod -Uri $Url -Method Post -ContentType "application/json; charset=utf-8" -Body $json
        return $resp
    } catch {
        # Use ${Url} so ':' doesn't break variable name
        Say "[ERROR] Failed POST to ${Url}: $($_.Exception.Message)" "Red"
        throw
    }
}

function Write-NifduFiles {
    param(
        [object[]]$Files
    )

    if (-not $Files -or $Files.Count -eq 0) {
        Say "[FILES] No files[] returned, nothing to write." "DarkYellow"
        return
    }

    Say "`n[FILES] Writing $($Files.Count) file(s) to disk..." "Cyan"

    foreach ($f in $Files) {
        $path     = $f.path
        $content  = $f.content
        $action   = $f.action
        $language = $f.language
        $status   = $f.status

        if (-not $path) {
            Say "  [SKIP] File with no path field." "DarkYellow"
            continue
        }

        if ($null -eq $content) {
            Say "  [WARN] File '$path' has null content." "DarkYellow"
        }

        $dir = Split-Path -Path $path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            Say "  [MKDIR] $dir" "DarkGray"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        if (-not $action) { $action = "write" }

        switch ($action) {
            "write" {
                Say "  [WRITE] $path ($language, $status)" "Green"
                Set-Content -LiteralPath $path -Value $content -Encoding UTF8
            }
            "propose" {
                # For now treat 'propose' same as 'write'
                Say "  [WRITE-PROPOSE] $path ($language, $status)" "DarkGreen"
                Set-Content -LiteralPath $path -Value $content -Encoding UTF8
            }
            default {
                Say "  [SKIP] $path — unsupported action '$action'" "DarkYellow"
            }
        }
    }
}

function Invoke-BuildWithLog {
    param(
        [string[]]$Commands
    )

    if (-not $Commands -or $Commands.Count -eq 0) {
        Say "[BUILD] No post_steps provided, nothing to run." "DarkYellow"
        return $true
    }

    Say "`n[BUILD] Running build / post_steps in $BuildDir" "Cyan"
    if (Test-Path $BuildLog) {
        Remove-Item $BuildLog -Force
    }

    $global:LASTEXITCODE = 0
    $overallSuccess = $true

    Push-Location $BuildDir
    try {
        foreach ($cmd in $Commands) {
            if (-not $cmd) { continue }
            Say "  [CMD] $cmd" "DarkGray"

            # run command and tee output to log
            cmd.exe /c $cmd 2>&1 |
                Tee-Object -FilePath $BuildLog -Append

            if ($LASTEXITCODE -ne 0) {
                Say "  [FAIL] Command failed with exit code $LASTEXITCODE" "Red"
                $overallSuccess = $false
                break
            }
        }
    }
    finally {
        Pop-Location
    }

    if ($overallSuccess) {
        Say "[BUILD] Build/post_steps completed successfully." "Green"
    } else {
        Say "[BUILD] Build/post_steps FAILED. See log: $BuildLog" "Red"
    }

    return $overallSuccess
}

# -------------------------------
# STEP 1: Call /api/codegen
# -------------------------------
Say "[STEP 1] Requesting codegen plan + files from /api/codegen..." "Yellow"

$codegenReq = @{
    project = $Project
    prompt  = $Prompt
    brain   = "auto"
    mode    = "vibe_coding"
}

$codegenResp = Invoke-NifduJsonPost -Url $CodegenUrl -Body $codegenReq

if (-not $codegenResp.status -or $codegenResp.status -ne "ok") {
    Say "[ERROR] /api/codegen returned non-ok status: $($codegenResp | ConvertTo-Json -Depth 10)" "Red"
    exit 1
}

# Write initial files
Write-NifduFiles -Files $codegenResp.files

# Prepare post_steps (fallback if not provided)
$postSteps = @()
if ($codegenResp.post_steps) {
    $postSteps = @($codegenResp.post_steps)
} else {
    # SIMPLE: no quoting needed, BuildDir has no spaces
    $postSteps = @("cmake --build $BuildDir --config Release")
    Say "[INFO] post_steps missing from response, using default build command." "DarkYellow"
}

# -------------------------------
# STEP 2: Build + Fix loop
# -------------------------------
$attempt = 0
$success = $false

while ($attempt -le $MaxFixLoops -and -not $success) {
    $attempt++
    Say "`n=== BUILD ATTEMPT #$attempt (of $($MaxFixLoops + 1)) ===" "Yellow"

    $success = Invoke-BuildWithLog -Commands $postSteps

    if ($success) {
        break
    }

    if ($attempt -gt $MaxFixLoops) {
        Say "`n[STOP] Maximum fix attempts reached, still failing." "Red"
        break
    }

    # -------------------------------
    # STEP 3: Call /api/chat with error_log to fix
    # -------------------------------
    Say "`n[STEP 3] Build failed. Calling /api/chat (mode=fix_errors) with error log..." "Yellow"

    if (!(Test-Path $BuildLog)) {
        Say "[WARN] Build log file not found at $BuildLog. Skipping fix_errors." "DarkYellow"
        break
    }

    $errorLogText = Get-Content $BuildLog -Raw

    $fixReq = @{
        mode      = "fix_errors"
        project   = $Project
        brain     = "auto"
        prompt    = "Fix compile errors for project $Project"
        error_log = $errorLogText
    }

    $fixResp = Invoke-NifduJsonPost -Url $ChatUrl -Body $fixReq

    if (-not $fixResp.status -or $fixResp.status -ne "ok") {
        Say "[ERROR] /api/chat (fix_errors) returned non-ok status: $($fixResp | ConvertTo-Json -Depth 10)" "Red"
        break
    }

    # Apply fixes
    if ($fixResp.files) {
        Write-NifduFiles -Files $fixResp.files
    } else {
        Say "[WARN] fix_errors response had no files[]." "DarkYellow"
    }

    if ($fixResp.post_steps) {
        $postSteps = @($fixResp.post_steps)
        Say "[INFO] Using updated post_steps from fix_errors response." "DarkGray"
    }
}

if ($success) {
    Say "`n=== NIFDU APP WRITER v2 — SUCCESS 🎉 ===" "Green"
    Say "You can now open: $BaseUrl/apps/$Project/" "Green"
    exit 0
} else {
    Say "`n=== NIFDU APP WRITER v2 — FAILED AFTER RETRIES ❌ ===" "Red"
    Say "Check build log: $BuildLog" "Red"
    exit 1
}
