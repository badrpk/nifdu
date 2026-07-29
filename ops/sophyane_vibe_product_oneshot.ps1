# ==============================================
# C:\nifdu\ops\sophyane_vibe_product_oneshot.ps1
# SOPHYANE / NIFDU — PRODUCT ONE-SHOT (AGENT 3)
# ----------------------------------------------
# Flow:
#   - You give a high-level product prompt
#   - Script calls NIFDU /api/chat (Agent 3)
#   - Applies any "files" actions to Sophyane app workspace
#   - Optionally runs `pnpm build` to validate
#
# Notes:
#   - This is ONE iteration (no auto re-loop on error yet)
#   - Uses NIFDU backend on http://127.0.0.1:8000/api/chat
#   - Targets C:\nifdu\src\apps\<Project>
# ==============================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$Project = "sophyane_live",

    # Backend API endpoint (NIFDU)
    [string]$Backend = "http://127.0.0.1:8000/api/chat",

    # If $true, will run `pnpm build` after writing files
    [bool]$RunBuild = $false
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$Text, [string]$Color = "Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

Say "`n=== SOPHYANE PRODUCT ONE-SHOT — AGENT 3 ===`n" "Yellow"
Say ("Project : {0}" -f $Project) "Cyan"
Say ("Backend : {0}" -f $Backend) "Cyan"
Say ("RunBuild: {0}" -f $RunBuild) "Cyan"

# ----------------------------------------------
# 1) Resolve workspace root
# ----------------------------------------------
$appRoot = Join-Path "C:\nifdu\src\apps" $Project
if (!(Test-Path $appRoot)) {
    Say ("App root not found: {0}" -f $appRoot) "Red"
    exit 1
}
Say ("Workspace: {0}" -f $appRoot) "Green"

# ----------------------------------------------
# 2) Build request payload for Agent 3
# ----------------------------------------------
$promptText = @"
You are NIFDU Agent 3, controlling a Next.js app called '{0}' inside Sophyane.

Constraints:
- The app lives under: {1}
- Use modern Next.js (app router) with TypeScript and React.
- Only write files inside this workspace (relative paths).
- Prefer paths like:
    app/page.tsx
    app/(routes)/<feature>/page.tsx
    components/<name>.tsx
    lib/<name>.ts
- Do NOT touch C++ NIFDU core or Caddy config.
- You may assume Tailwind is available.

User high-level product spec:
{2}
"@ -f $Project, $appRoot, $Prompt

$payload = @{
    project = $Project
    mode    = "vibe_coding"
    brain   = "auto"
    prompt  = $promptText
}

$bodyJson = $payload | ConvertTo-Json -Depth 10
Say "`nCalling NIFDU /api/chat (Agent 3) ..." "Yellow"

# ----------------------------------------------
# 3) Call /api/chat and get JSON
# ----------------------------------------------
try {
    $resp = Invoke-RestMethod `
        -Uri $Backend `
        -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Body $bodyJson
} catch {
    Say ("ERROR calling backend: {0}" -f $_.Exception.Message) "Red"
    exit 1
}

$preview = ($resp | ConvertTo-Json -Depth 6)
$previewLen = [Math]::Min(300, $preview.Length)
Say "`n--- Agent 3 RAW RESPONSE (preview) ---" "DarkGray"
Say $preview.Substring(0, $previewLen) "DarkGray"
Say "--------------------------------------`n" "DarkGray"

if (-not $resp.files) {
    Say "No 'files' array in response — nothing to write. Exiting." "Red"
    exit 0
}

# ----------------------------------------------
# 4) Apply file actions
# ----------------------------------------------
Say "Applying file actions from Agent 3 ..." "Yellow"

$writeCount  = 0
$appendCount = 0
$skipCount   = 0

foreach ($f in $resp.files) {
    $action  = $f.action
    $content = $f.content
    $path    = $f.path

    if (-not $path) {
        $skipCount++
        Say "  [SKIP] Missing path in file entry." "DarkGray"
        continue
    }

    # Resolve path relative to appRoot if not rooted
    if (-not [System.IO.Path]::IsPathRooted($path)) {
        $fullPath = Join-Path $appRoot $path
    } else {
        $fullPath = $path
    }

    $dir = Split-Path $fullPath -Parent
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    switch ($action) {
        "write" {
            Say ("  [WRITE] {0}" -f $fullPath) "Green"
            Set-Content -Path $fullPath -Value $content -Encoding UTF8
            $writeCount++
        }
        "append" {
            Say ("  [APPEND] {0}" -f $fullPath) "Green"
            Add-Content -Path $fullPath -Value $content -Encoding UTF8
            $appendCount++
        }
        default {
            # Treat unknown actions as "propose" — write under _proposed
            $relPath  = [System.IO.Path]::GetFileName($path)
            $proposedDir = Join-Path $appRoot "_proposed"
            if (!(Test-Path $proposedDir)) {
                New-Item -ItemType Directory -Path $proposedDir -Force | Out-Null
            }
            $proposedPath = Join-Path $proposedDir $relPath

            Say ("  [PROPOSE:{0}] {1} -> {2}" -f $action, $path, $proposedPath) "DarkYellow"
            Set-Content -Path $proposedPath -Value $content -Encoding UTF8
            $skipCount++
        }
    }
}

Say "`nFile actions summary:" "Yellow"
Say ("  Writes : {0}" -f $writeCount) "Green"
Say ("  Appends: {0}" -f $appendCount) "Green"
Say ("  Other  : {0}" -f $skipCount) "DarkYellow"

# ----------------------------------------------
# 5) Optional: run pnpm build
# ----------------------------------------------
if ($RunBuild) {
    Say "`nRunning 'pnpm build' for $Project ..." "Yellow"
    Push-Location $appRoot
    try {
        & pnpm build
        $exitCode = $LASTEXITCODE
        Say ("pnpm build exit code: {0}" -f $exitCode) "Green"
    } catch {
        Say ("Build failed: {0}" -f $_.Exception.Message) "Red"
    }
    Pop-Location
}

Say "`n=== DONE: Sophyane product one-shot finished ===`n" "Green"
