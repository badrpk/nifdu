param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [Alias("ProductBriefPath")]
    [string]$Prompt
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$m, [string]$c = "Gray")
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

Say "`n=== NIFDU AGENT 3 - FULL PRODUCT VIBE CODING ONE-SHOT ===`n" "Yellow"
Say "Project : $Project" "Cyan"
Say "Prompt  : $Prompt`n" "Cyan"

# 1) Canonical project layout
$Root        = "C:/nifdu/src/apps/$Project"
$WebRoot     = Join-Path $Root "web"
$BackendRoot = Join-Path $Root "backend"
$MobileRoot  = Join-Path $Root "mobile"
$AssetsRoot  = Join-Path $Root "assets"
$PkgRoot     = Join-Path $Root "packages"
$DiagRoot    = "C:/nifdu/build/_diag"

foreach ($dir in @($Root, $WebRoot, $BackendRoot, $MobileRoot, $AssetsRoot, $PkgRoot, $DiagRoot)) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Say "Project layout ensured under $Root" "Green"

# 2) Build Agent 3 super-prompt using simple lines
$SystemPromptLines = @()

$SystemPromptLines += "You are NIFDU Agent 3, an advanced vibe-coding AI running inside a C++ monolith."
$SystemPromptLines += ""
$SystemPromptLines += "Context:"
$SystemPromptLines += "- You run behind the /api/chat endpoint with mode=vibe_coding."
$SystemPromptLines += "- Core system is C++ plus PowerShell. You may generate other stacks for APPS (not for the NIFDU core)."
$SystemPromptLines += "- NIFDU has an AV engine that can render MP4 videos and audio using /api/av/*."
$SystemPromptLines += ""
$SystemPromptLines += "Goal:"
$SystemPromptLines += "From a single human product brief, create a full product in one pass."
$SystemPromptLines += ""
$SystemPromptLines += "WEB FRONTEND:"
$SystemPromptLines += "- Put all web code under: $WebRoot"
$SystemPromptLines += "- Prefer React + Vite + Tailwind or Next.js."
$SystemPromptLines += "- Include at least: landing page, feature/demo page, and a page that embeds AV media."
$SystemPromptLines += ""
$SystemPromptLines += "BACKEND / API SERVICE:"
$SystemPromptLines += "- Put backend code under: $BackendRoot"
$SystemPromptLines += "- Prefer a C++ HTTP server or C++ library that can be integrated with NIFDU."
$SystemPromptLines += "- Only use Node.js or TypeScript for app-level logic if really needed."
$SystemPromptLines += ""
$SystemPromptLines += "ANDROID AND iOS APPS:"
$SystemPromptLines += "- Put mobile code under: $MobileRoot"
$SystemPromptLines += "- Use React Native or Flutter."
$SystemPromptLines += "- Show the main product UI and at least one screen that uses the NIFDU video or audio."
$SystemPromptLines += ""
$SystemPromptLines += "NIFDU AV INTEGRATION:"
$SystemPromptLines += "- Do not call HTTP from inside the generated code."
$SystemPromptLines += "- Instead, create AV JSON files at:"
$SystemPromptLines += "  $AssetsRoot/av_plan_$Project.json"
$SystemPromptLines += "  $AssetsRoot/av_control_$Project.json"
$SystemPromptLines += "- Assume NIFDU will later generate media files at:"
$SystemPromptLines += "  $AssetsRoot/videos/intro.mp4"
$SystemPromptLines += "  $AssetsRoot/audio/theme.mp3"
$SystemPromptLines += "- Use these paths in the web and mobile UIs as if the media already exists."
$SystemPromptLines += ""
$SystemPromptLines += "DOWNLOADABLE PACKAGES:"
$SystemPromptLines += "- Under $PkgRoot create packaging scripts only, for example:"
$SystemPromptLines += "  make_web_package.ps1, make_backend_package.ps1, make_mobile_package.ps1."
$SystemPromptLines += "- Each script should zip its part of the project into files like:"
$SystemPromptLines += "  web_$Project.zip, backend_$Project.zip, mobile_$Project.zip."
$SystemPromptLines += ""
$SystemPromptLines += "QUALITY:"
$SystemPromptLines += "- Write realistic, production-like code."
$SystemPromptLines += "- Do not generate Python."
$SystemPromptLines += "- Prefer C++, JavaScript or TypeScript, Dart, Kotlin or Swift as needed."
$SystemPromptLines += ""
$SystemPromptLines += "FILE ACTION FORMAT:"
$SystemPromptLines += "- Respond with JSON containing an engine field and a files array."
$SystemPromptLines += "- Each item in files should include: action, path, language, and content."
$SystemPromptLines += "- All paths must stay inside the root folder: $Root"
$SystemPromptLines += ""
$SystemPromptLines += "HUMAN BRIEF:"
$SystemPromptLines += $Prompt
$SystemPromptLines += ""
$SystemPromptLines += "Now design and output the complete file action list to realize this product."

$SystemPrompt = $SystemPromptLines -join "`n"

$Body = @{
    project = $Project
    brain   = "auto"
    mode    = "vibe_coding"
    prompt  = $SystemPrompt
}

$Json     = $Body | ConvertTo-Json -Depth 20
$DiagFile = Join-Path $DiagRoot ("agent3_full_product_" + $Project + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".json")
$Json | Out-File -FilePath $DiagFile -Encoding UTF8

Say "Sending full-product vibe coding request to NIFDU Agent 3..." "Yellow"

function Write-Agent3Files {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Response,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    if (-not $Response.files) {
        Say "No files[] array present in Agent 3 response; nothing to write." "DarkYellow"
        return
    }

    $count = 0
    foreach ($f in $Response.files) {
        if (-not $f.path -or -not $f.content) { continue }

        $path = [string]$f.path
        $action = [string]$f.action

        # Safety: only write inside $RootPath
        if ($path -notlike "$RootPath*") {
            Say "[SKIP] Path outside root: $path" "DarkYellow"
            continue
        }

        if ($action -ne "write") {
            Say "[SKIP] Unsupported action '$action' for $path" "DarkYellow"
            continue
        }

        $dir = Split-Path $path -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        Set-Content -Path $path -Value $f.content -Encoding UTF8
        $count++
        Say "  [write] $path" "Gray"
    }

    Say "Total files written: $count" "Green"
}

try {
    $Response = Invoke-RestMethod `
        -Uri "http://127.0.0.1/api/chat" `
        -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Body $Json

    $Response | ConvertTo-Json -Depth 20 | Out-File -FilePath ($DiagFile + ".response.json") -Encoding UTF8

    Say "`n[OK] NIFDU Agent 3 responded." "Green"

    # NEW: actually write files from Response.files[]
    Say "Materialising Agent 3 files under $Root ..." "Yellow"
    Write-Agent3Files -Response $Response -RootPath $Root

}
catch {
    Say "`n[FATAL] Failed to contact /api/chat or parse response." "Red"
    Say $_.Exception.Message "Red"
    Say "Check that nifdu.exe is running on http://127.0.0.1 and that /api/chat works." "Yellow"
    exit 1
}

Say "`n=== NIFDU AGENT 3 - FULL PRODUCT ONE-SHOT COMPLETED (REQUEST + WRITE) ===`n" "Yellow"
