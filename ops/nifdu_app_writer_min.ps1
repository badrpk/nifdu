param(
    [string]$Project      = "todo_app_urdu",
    [string]$Prompt       = "Small Urdu todo app in C++ + HTML with full CRUD functionality",
    [string]$BaseUrl      = "http://127.0.0.1",
    [string]$BuildDir     = "C:\nifdu\build"
)

$ErrorActionPreference = "Stop"

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

Say "`n=== NIFDU APP WRITER MIN — Project: $Project ===`n" "Yellow"

# --------------------------------------------------------------------
# Paths / endpoints
# --------------------------------------------------------------------
$CodegenUrl = "$BaseUrl/api/codegen"
$DiagDir    = "C:\nifdu\_diag"

if (!(Test-Path $DiagDir)) {
    New-Item -ItemType Directory -Path $DiagDir -Force | Out-Null
}
$BuildLog = Join-Path $DiagDir ("build_{0}.log" -f $Project)

# --------------------------------------------------------------------
# Call /api/codegen
# --------------------------------------------------------------------
$body = @{
    project = $Project
    prompt  = $Prompt
    brain   = "auto"
    mode    = "vibe_coding"
}

$bodyJson = $body | ConvertTo-Json -Depth 10

Say "[STEP 1] POST /api/codegen" "Yellow"
Say $bodyJson "DarkGray"

try {
    $resp = Invoke-RestMethod -Uri $CodegenUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $bodyJson
} catch {
    Say "[ERROR] HTTP error calling /api/codegen: $($_.Exception.Message)" "Red"
    exit 1
}

if (-not $resp.status -or $resp.status -ne "ok") {
    Say "[ERROR] /api/codegen returned non-ok status:" "Red"
    $resp | ConvertTo-Json -Depth 10 | Write-Host
    exit 1
}

# --------------------------------------------------------------------
# Write files[] to disk
# --------------------------------------------------------------------
$files = $resp.files

if (-not $files -or $files.Count -eq 0) {
    Say "[FILES] No files[] returned from /api/codegen, nothing to write." "DarkYellow"
} else {
    Say "`n[FILES] Writing $($files.Count) file(s)..." "Cyan"

    foreach ($f in $files) {
        $path     = $f.path
        $content  = $f.content
        $language = $f.language
        $status   = $f.status
        $action   = $f.action

        if (-not $path) {
            Say "  [SKIP] File with no path." "DarkYellow"
            continue
        }

        if (-not $action) {
            $action = "write"
        }

        $dir = Split-Path -Path $path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            Say "  [MKDIR] $dir" "DarkGray"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        if ($action -eq "write" -or $action -eq "propose") {
            Say "  [WRITE] $path ($language, $status)" "Green"
            Set-Content -LiteralPath $path -Value $content -Encoding UTF8
        } else {
            Say "  [SKIP] $path — unsupported action '$action'" "DarkYellow"
        }
    }
}

# --------------------------------------------------------------------
# Build step
# --------------------------------------------------------------------
Say "`n[STEP 2] Building in $BuildDir" "Yellow"

if (Test-Path $BuildLog) {
    Remove-Item $BuildLog -Force
}

Push-Location $BuildDir
try {
    # Simple: one build command. BuildDir has no spaces, so no fancy quoting.
    $cmd = "cmake --build . --config Release"
    Say "  [CMD] $cmd" "DarkGray"

    cmd.exe /c $cmd 2>&1 | Tee-Object -FilePath $BuildLog -Append

    if ($LASTEXITCODE -ne 0) {
        Say "[BUILD] FAILED with exit code $LASTEXITCODE" "Red"
        Say "Check log: $BuildLog" "Red"
        exit 1
    } else {
        Say "[BUILD] SUCCESS." "Green"
        Say "You can now open: $BaseUrl/apps/$Project/" "Green"
        exit 0
    }
}
finally {
    Pop-Location
}
