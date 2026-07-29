# ==============================================
# C:\nifdu\ops\nifdu_sophyane_vibe_publish_from_api.ps1
# NIFDU Agent 3 → generate site via /api/chat
# and publish it directly to sophyane.com webroot.
#
# Strategy:
#   1) Try backend:  http://127.0.0.1:8000/api/chat
#      - Disable compression (Accept-Encoding: identity)
#   2) If backend fails, fallback:
#      https://127.0.0.1/api/chat  (Host: sophyane.com via Caddy)
#   3) Take files[0].content (HTML) and write:
#      C:\webroot\sophyane.com\www\index.html
#   4) Smoke test HTTP and HTTPS via Caddy
# ==============================================

param()

$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$Text,
        [string]$Color = "Gray"
    )
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

Say "`n=== NIFDU / SOPHYANE VIBE PUBLISH (FROM /api/chat) ===`n" "Yellow"

# ------------------------------------------------------------------
# 1) Prepare request body
# ------------------------------------------------------------------

$bodyJson = @{
    project = "vibe_web"
    prompt  = "make cat types website"
    brain   = "auto"
    mode    = "vibe_coding"
} | ConvertTo-Json -Depth 10

# Common header for disabling compression (helps old PowerShell)
$noCompressionHeader = @{
    "Accept-Encoding" = "identity"
}

# ------------------------------------------------------------------
# 2) Try backend /api/chat on port 8000 first
# ------------------------------------------------------------------

$resp   = $null
$source = "none"

$backendUrl = "http://127.0.0.1:8000/api/chat"
Say ("Trying backend first: {0}" -f $backendUrl) "Cyan"

try {
    $resp = Invoke-WebRequest `
        -Uri $backendUrl `
        -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Headers $noCompressionHeader `
        -UseBasicParsing `
        -Body $bodyJson

    $source = "backend"
    Say ("Backend /api/chat => {0}" -f $resp.StatusCode) "Green"
} catch {
    Say ("Backend /api/chat ERROR: {0}" -f $_.Exception.Message) "DarkYellow"
    $resp = $null
}

# ------------------------------------------------------------------
# 3) If backend failed, fallback via Caddy HTTPS
# ------------------------------------------------------------------

if (-not $resp -or $resp.StatusCode -ne 200) {
    Say "Falling back to Caddy HTTPS (sophyane.com)..." "Yellow"

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    $caddyHeaders = @{
        Host             = "sophyane.com"
        "Accept-Encoding" = "identity"
    }

    $caddyUrl = "https://127.0.0.1/api/chat"

    try {
        $resp = Invoke-WebRequest `
            -Uri $caddyUrl `
            -Method Post `
            -ContentType "application/json; charset=utf-8" `
            -Headers $caddyHeaders `
            -UseBasicParsing `
            -Body $bodyJson

        $source = "caddy"
        Say ("Caddy HTTPS /api/chat => {0}" -f $resp.StatusCode) "Green"
    } catch {
        Say ("FATAL: Caddy HTTPS /api/chat also failed: {0}" -f $_.Exception.Message) "Red"
        exit 1
    }
}

if (-not $resp -or $resp.StatusCode -ne 200) {
    Say "FATAL: No successful /api/chat response from either backend or Caddy." "Red"
    exit 1
}

Say ("Using response source: {0}" -f $source) "DarkGreen"

# ------------------------------------------------------------------
# 4) Parse JSON and extract HTML
# ------------------------------------------------------------------

$data = $resp.Content | ConvertFrom-Json

if (-not $data.files -or $data.files.Count -eq 0) {
    Say "ERROR: /api/chat returned no files array or it's empty." "Red"
    exit 1
}

$file = $null
foreach ($f in $data.files) {
    $pathStr = $f.path.ToString()
    $lang    = $f.language

    if ($lang -eq "html" -or $pathStr.ToLower().EndsWith(".html")) {
        $file = $f
        break
    }
}

if (-not $file) {
    Say "ERROR: No HTML file found in response files[]." "Red"
    exit 1
}

$htmlContent = $file.content
$origPath    = $file.path

Say "Selected file from /api/chat:" "DarkGreen"
Say ("  path     = {0}" -f $origPath) "DarkGreen"
Say ("  language = {0}" -f $file.language) "DarkGreen"

if ([string]::IsNullOrWhiteSpace($htmlContent)) {
    Say "ERROR: Selected file has empty content." "Red"
    exit 1
}

# ------------------------------------------------------------------
# 5) Publish HTML to sophyane.com webroot
# ------------------------------------------------------------------

$dstRoot  = "C:\webroot\sophyane.com\www"
$dstIndex = Join-Path $dstRoot "index.html"

if (-not (Test-Path $dstRoot)) {
    Say ("Creating target directory: {0}" -f $dstRoot) "Cyan"
    New-Item -ItemType Directory -Path $dstRoot -Force | Out-Null
} else {
    Say ("Target directory exists: {0}" -f $dstRoot) "DarkGreen"
}

if (Test-Path $dstIndex) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$dstIndex.bak_$timestamp"
    Say ("Backing up existing index.html to: {0}" -f $backup) "DarkYellow"
    Copy-Item $dstIndex $backup -Force
} else {
    Say "No existing index.html at target (clean publish)." "DarkGreen"
}

Say ("Writing new index.html -> {0}" -f $dstIndex) "Cyan"
Set-Content -Path $dstIndex -Value $htmlContent -Encoding UTF8
Say "Publish write complete." "Green"

# ------------------------------------------------------------------
# 6) HTTP and HTTPS smoke tests through Caddy
# ------------------------------------------------------------------

$ErrorActionPreference = "Continue"

Say "`n=== HTTP SMOKE (expect 308 redirect) ===" "Yellow"
try {
    $httpRes = Invoke-WebRequest `
        -Uri "http://127.0.0.1/" `
        -Headers @{ Host = "sophyane.com" } `
        -UseBasicParsing `
        -MaximumRedirection 0

    Say ("HTTP / (sophyane.com) => {0}" -f $httpRes.StatusCode) "Green"
    if ($httpRes.Headers.Location) {
        Say ("Location: {0}" -f $httpRes.Headers.Location) "DarkCyan"
    }
} catch {
    Say ("HTTP / (sophyane.com) ERROR: {0}" -f $_.Exception.Message) "Red"
}

Say "`n=== HTTPS SMOKE (content snippet) ===" "Yellow"

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$httpsHeaders = @{
    Host             = "sophyane.com"
    "Accept-Encoding" = "identity"
}

try {
    $httpsRes = Invoke-WebRequest `
        -Uri "https://127.0.0.1/" `
        -Headers $httpsHeaders `
        -UseBasicParsing

    Say ("HTTPS / (sophyane.com) => {0}" -f $httpsRes.StatusCode) "Green"

    $snippet = $httpsRes.Content
    if ($snippet.Length -gt 300) {
        $snippet = $snippet.Substring(0, 300) + "`n..."
    }

    Say "`n--- HTML SNIPPET ---`n" "DarkCyan"
    Write-Host $snippet
    Say "`n--- END SNIPPET ---`n" "DarkCyan"
} catch {
    Say ("HTTPS / (sophyane.com) ERROR: {0}" -f $_.Exception.Message) "Red"
}

Say "`n=== DONE: sophyane.com now serving latest /api/chat HTML ===`n" "Magenta"
function sophyane {
    param(
        # Optional: let user type prompt inline like: sophyane make dog website
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$PromptWords
    )

    # If user typed words after 'sophyane', join them
    $promptText = $PromptWords -join " "

    # If nothing was passed, ask interactively
    if (-not $promptText -or $promptText.Trim().Length -eq 0) {
        Write-Host ""
        Write-Host "=== SOPHYANE VIBE CODING LAUNCHER ===" -ForegroundColor Yellow
        Write-Host "Describe the product you want to build (e.g. 'SaaS dashboard', 'Dog website', 'AI blog'):" -ForegroundColor Cyan
        $promptText = Read-Host "Product prompt"
    }

    if (-not $promptText -or $promptText.Trim().Length -eq 0) {
        Write-Host "No prompt provided. Aborting." -ForegroundColor Red
        return
    }

    $scriptPath = "C:\nifdu\ops\sophyane_vibe_product_oneshot.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Cannot find $scriptPath" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ">>> Sending to NIFDU / Agent 3:" -ForegroundColor Yellow
    Write-Host "    $promptText" -ForegroundColor Green
    Write-Host ""

    # Call your one-shot Product script
    & $scriptPath -Prompt $promptText -Project "sophyane_live" -RunBuild:$false

    # After generation, open Sophyane live site
    Write-Host "Opening sophyane.com ..." -ForegroundColor Yellow
    Start-Process "https://sophyane.com"
}

