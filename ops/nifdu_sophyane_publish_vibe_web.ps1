# ==============================================
# C:\nifdu\ops\nifdu_sophyane_publish_vibe_web.ps1
# Publish the "Cat Types" vibe_web site to sophyane.com
#  - Source: C:\vibe_web\index.html
#  - Target root: C:\webroot\sophyane.com\www
#  - Then smoke-test via Caddy (HTTP + HTTPS)
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

Say "`n=== NIFDU / SOPHYANE PUBLISH vibe_web ===`n" "Yellow"

# Paths
$srcHtml  = "C:\vibe_web\index.html"
$dstRoot  = "C:\webroot\sophyane.com\www"
$dstIndex = Join-Path $dstRoot "index.html"

# 1) Sanity check source
if (-not (Test-Path $srcHtml)) {
    Say "ERROR: Source HTML not found: $srcHtml" "Red"
    exit 1
}
Say "Source HTML: $srcHtml" "Green"

# 2) Ensure target root exists
if (-not (Test-Path $dstRoot)) {
    Say "Creating target directory: $dstRoot" "Cyan"
    New-Item -ItemType Directory -Path $dstRoot -Force | Out-Null
} else {
    Say "Target directory already exists: $dstRoot" "DarkGreen"
}

# 3) Backup existing index.html if present
if (Test-Path $dstIndex) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$dstIndex.bak_$timestamp"
    Say "Backing up existing index.html to: $backup" "DarkYellow"
    Copy-Item $dstIndex $backup -Force
} else {
    Say "No existing index.html at target (clean publish)." "DarkGreen"
}

# 4) Copy new index.html
Say "Copying $srcHtml -> $dstIndex" "Cyan"
Copy-Item $srcHtml $dstIndex -Force

Say "Publish step complete." "Green"

# 5) HTTP smoke test (expect 308 redirect to HTTPS)
Say "`n=== HTTP SMOKE (expect 308 redirect) ===`" "Yellow"
$ErrorActionPreference = "Continue"
try {
    $httpRes = Invoke-WebRequest `
        -Uri 'http://127.0.0.1/' `
        -Headers @{ Host = 'sophyane.com' } `
        -UseBasicParsing `
        -MaximumRedirection 0

    Say ("HTTP / (sophyane.com) => {0}" -f $httpRes.StatusCode) "Green"
    if ($httpRes.Headers.Location) {
        Say ("Location: {0}" -f $httpRes.Headers.Location) "DarkCyan"
    }
} catch {
    Say ("HTTP / (sophyane.com) ERROR: {0}" -f $_.Exception.Message) "Red"
}

# 6) HTTPS smoke test: grab small snippet of HTML
Say "`n=== HTTPS SMOKE (content snippet) ===`" "Yellow"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

try {
    $commonHeaders = @{
        Host            = 'sophyane.com'
        'Accept-Encoding' = 'identity'
    }

    $httpsRes = Invoke-WebRequest `
        -Uri 'https://127.0.0.1/' `
        -Headers $commonHeaders `
        -UseBasicParsing

    Say ("HTTPS / (sophyane.com) => {0}" -f $httpsRes.StatusCode) "Green"

    # Show first ~300 chars of content
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

Say "`n=== DONE: vibe_web now published to sophyane.com ===`n" "Magenta"
