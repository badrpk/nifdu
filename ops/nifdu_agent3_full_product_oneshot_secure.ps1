# ==============================================
# C:\nifdu\ops\nifdu_agent3_full_product_oneshot_secure.ps1
# NIFDU AGENT 3 — SECURE AUTONOMOUS PRODUCT LAUNCH
# ==============================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Project,          # e.g. "snake_sophyane_full"

    [Parameter(Mandatory = $true)]
    [string]$ProductBriefPath  # e.g. C:\nifdu\ops\snake_brief.txt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------
# Console helper
# ------------------------------------------------
function Say {
    param([string]$m, [string]$c = "Gray")
    try {
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

# ------------------------------------------------
# .env loader — canonical, hardened to C:\ENV\.env
# ------------------------------------------------
$DotEnvPath = "C:\ENV\.env"

function Load-DotEnv {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw ".env not found at $Path. Make sure C:\ENV\.env exists."
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^\s*#') { return }
        if ($_ -match '^\s*$') { return }

        if ($_ -match '^\s*([^=]+)=(.*)$') {
            $name  = $matches[1].Trim()
            $value = $matches[2].Trim()

            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            ${env:$name} = $value
        }
    }
}

Load-DotEnv -Path $DotEnvPath

# ------------------------------------------------
# Core paths
# ------------------------------------------------
$NifduBaseUrl   = "http://127.0.0.1"
$ExePath        = "C:\nifdu\build\Release\nifdu.exe"

$AppRoot        = "C:\nifdu\src\apps\$Project"
$WebRoot        = Join-Path $AppRoot "web"
$MobileRoot     = Join-Path $AppRoot "mobile"
$AndroidRoot    = Join-Path $MobileRoot "android"
$IosRoot        = Join-Path $MobileRoot "ios"

$SiteRoot       = "C:\webroot\nifdu.com\www"
$SiteAppsRoot   = Join-Path $SiteRoot "apps"
$SiteProject    = Join-Path $SiteAppsRoot $Project

$DeliverableRoot = "C:\nifdu\deliverables"
$Timestamp       = Get-Date -Format 'yyyyMMdd_HHmmss'
$DeliverableZip  = Join-Path $DeliverableRoot ("{0}_{1}.zip" -f $Project, $Timestamp)

# ------------------------------------------------
# Credentials from .env (NEVER hard-code)
# ------------------------------------------------
$GoDaddyApiKey    = $env:GODADDY_API_KEY
$GoDaddyApiSecret = $env:GODADDY_API_SECRET
$GoDaddyApiBase   = $env:GODADDY_API_BASE

$OpenAIApiKey     = $env:OPENAI_API_KEY

# ------------------------------------------------
# Feature flags (SAFE DEFAULTS)
# ------------------------------------------------
$EnableDomainPurchase   = $false   # GoDaddy
$EnablePlayStorePublish = $false   # Google Play
$EnableAppStorePublish  = $false   # App Store Connect

$TargetDomain = "sophyane.com"

# ------------------------------------------------
# (Optional) External API stubs — for simulation
# ------------------------------------------------
function Invoke-GoDaddyPurchaseSim {
    param([string]$Domain)
    Say "[SIM] Would purchase domain: $Domain via GoDaddy." "DarkYellow"
}

function Invoke-GooglePlayUploadSim {
    param([string]$AABPath)
    Say "[SIM] Would upload Android AAB to Google Play: $AABPath" "DarkYellow"
}

function Invoke-AppleStoreConnectUploadSim {
    param([string]$IPAPath)
    Say "[SIM] Would upload iOS IPA to App Store Connect: $IPAPath" "DarkYellow"
}

function Invoke-SendEmailSim {
    param([string]$File)
    Say "[SIM] Would email deliverable to client: $File" "DarkYellow"
}

# =============================================================================
# STEP 0 — Ensure NIFDU monolith is running
# =============================================================================
Say "`n=== NIFDU AGENT 3 FULL PRODUCT ONE-SHOT (SECURE) ===`n" "Yellow"

Say "[STEP 0] Ensuring NIFDU monolith is running on port 80..." "Cyan"
Get-Process nifdu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process -FilePath $ExePath -ArgumentList "--port 80" -NoNewWindow -PassThru | Out-Null
Start-Sleep -Seconds 3

# =============================================================================
# STEP 1 — Read product brief and call Agent 3
# =============================================================================
if (-not (Test-Path $ProductBriefPath)) {
    throw "Product brief not found at $ProductBriefPath"
}

$brief = Get-Content -LiteralPath $ProductBriefPath -Raw

Say "`n[STEP 1] Sending product brief to NIFDU Agent 3 (/api/chat)...`n" "Cyan"

$body = @{
    project = $Project
    prompt  = $brief
    brain   = "auto"
    mode    = "vibe_coding"
} | ConvertTo-Json -Depth 10

$agentResponse = Invoke-RestMethod `
    -Uri "$NifduBaseUrl/api/chat" `
    -Method Post `
    -ContentType "application/json; charset=utf-8" `
    -Body $body

Say "[OK] Agent 3 responded. Applying file actions to disk..." "Green"

if ($agentResponse.files) {
    foreach ($f in $agentResponse.files) {
        $path    = $f.path
        $content = $f.content
        $action  = $f.action

        if (-not $path) { continue }

        $dir = Split-Path $path -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        switch ($action) {
            "write" {
                Set-Content -LiteralPath $path -Value $content -Encoding UTF8
                Say ("[WRITE] {0}" -f $path) "Gray"
            }
            "append" {
                Add-Content -LiteralPath $path -Value $content -Encoding UTF8
                Say ("[APPEND] {0}" -f $path) "Gray"
            }
            default {
                Set-Content -LiteralPath $path -Value $content -Encoding UTF8
                Say ("[WRITE*] {0}" -f $path) "Gray"
            }
        }
    }
} else {
    Say "[WARN] Agent response had no files[]; creating minimal web placeholder." "DarkYellow"
    New-Item -ItemType Directory -Path $WebRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $WebRoot "index.html") -Value "<h1>$Project placeholder</h1>" -Encoding UTF8
}

# =============================================================================
# STEP 2 — Build Web Frontend (if JS project detected)
# =============================================================================
Say "`n[STEP 2] Building web frontend (if package.json / Vite project exists)...`n" "Cyan"

if (-not (Test-Path $WebRoot)) {
    Say ("[WARN] Web root {0} does not exist. Skipping web build." -f $WebRoot) "DarkYellow"
} else {
    Push-Location $WebRoot
    if (Test-Path "package.json") {
        Say "[INFO] package.json found. Running npm install + npm run build..." "Gray"
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Say "[WARN] npm not found on PATH. Skipping JS build; serving static files only." "DarkYellow"
        } else {
            npm install
            npm run build
        }
    } else {
        Say "[INFO] No package.json; treating $WebRoot as plain static assets." "Gray"
    }
    Pop-Location
}

if (Test-Path (Join-Path $WebRoot "dist")) {
    $SourceDir = Join-Path $WebRoot "dist"
} elseif (Test-Path (Join-Path $WebRoot "build")) {
    $SourceDir = Join-Path $WebRoot "build"
} else {
    $SourceDir = $WebRoot
}

# =============================================================================
# STEP 3 — Deploy web app to live NIFDU HTTP surface
# =============================================================================
Say "`n[STEP 3] Deploying web assets to C:\webroot\nifdu.com\www\apps\$Project ...`n" "Cyan"

New-Item -ItemType Directory -Path $SiteAppsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $SiteProject  -Force | Out-Null

Get-ChildItem -Path $SiteProject -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

if (Test-Path $SourceDir) {
    Copy-Item -Path (Join-Path $SourceDir "*") -Destination $SiteProject -Recurse -Force
    Say "[OK] Deployed web assets to live webroot." "Green"
} else {
    Say ("[WARN] SourceDir {0} does not exist; creating placeholder index.html." -f $SourceDir) "DarkYellow"
    $Placeholder = "<h1>$Project placeholder</h1><p>Assets missing.</p>"
    Set-Content -LiteralPath (Join-Path $SiteProject "index.html") -Value $Placeholder -Encoding UTF8
}

# =============================================================================
# STEP 4 — OPTIONAL: Domain purchase + DNS via GoDaddy API
# =============================================================================
if ($EnableDomainPurchase) {
    Say "`n[STEP 4] Domain purchase via GoDaddy API (ENABLED)..." "Cyan"

    if (-not $GoDaddyApiKey -or -not $GoDaddyApiSecret -or -not $GoDaddyApiBase) {
        Say "[FATAL] GoDaddy credentials/base URL missing in .env. Aborting domain step." "Red"
    } else {
        $headers = @{
            "Authorization" = ("sso-key {0}:{1}" -f $GoDaddyApiKey, $GoDaddyApiSecret)
            "Accept"        = "application/json"
            "Content-Type"  = "application/json"
        }

        try {
            $availability = Invoke-RestMethod `
                -Uri "$GoDaddyApiBase/domains/available?domain=$TargetDomain" `
                -Method Get `
                -Headers $headers

            if (-not $availability.available) {
                Say ("[WARN] Domain {0} is not available. Skipping purchase." -f $TargetDomain) "DarkYellow"
            } else {
                Say ("[INFO] Domain {0} is available. (Purchase call omitted for safety.)" -f $TargetDomain) "Gray"
                # real purchase call would go here
            }

            $PublicIp = "<YOUR_PUBLIC_IP>"  # non-secret
            $dnsBody = @(
                @{
                    type = "A"
                    name = "@"
                    data = $PublicIp
                    ttl  = 600
                }
            ) | ConvertTo-Json -Depth 10

            Invoke-RestMethod `
                -Uri "$GoDaddyApiBase/domains/$TargetDomain/records/A/@ " `
                -Method Put `
                -Headers $headers `
                -Body $dnsBody

            Say "[OK] DNS A record updated for $TargetDomain." "Green"
        } catch {
            Say "[WARN] GoDaddy API call failed (network/auth). Check credentials and IP whitelist." "DarkYellow"
        }
    }
} else {
    Say "`n[STEP 4] Domain purchase via GoDaddy API is DISABLED (EnableDomainPurchase = `$false)." "Gray"
}

# =============================================================================
# STEP 5 — OPTIONAL: Android build & Google Play upload
# =============================================================================
if ($EnablePlayStorePublish) {
    Say "`n[STEP 5] Android build & Play Store upload (ENABLED)..." "Cyan"

    if (-not (Test-Path $AndroidRoot)) {
        Say ("[WARN] Android project root not found at {0}. Skipping Android step." -f $AndroidRoot) "DarkYellow"
    } else {
        Push-Location $AndroidRoot
        if (-not (Test-Path "gradlew")) {
            Say "[WARN] gradlew not found. Ensure a Gradle Android project exists here." "DarkYellow"
        } else {
            .\gradlew assembleRelease
            Say "[OK] Android release build finished." "Green"

            $AABPath = Get-ChildItem -Path . -Recurse -Include "*.aab","*.apk" -ErrorAction SilentlyContinue |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 1 -ExpandProperty FullName

            if ($AABPath) {
                Invoke-GooglePlayUploadSim -AABPath $AABPath
            } else {
                Say "[WARN] No APK/AAB found after build." "DarkYellow"
            }
        }
        Pop-Location
    }
} else {
    Say "`n[STEP 5] Android / Play Store auto-publish is DISABLED (EnablePlayStorePublish = `$false)." "Gray"
}

# =============================================================================
# STEP 6 — OPTIONAL: iOS prep & App Store Connect upload
# =============================================================================
if ($EnableAppStorePublish) {
    Say "`n[STEP 6] iOS App Store Connect upload (ENABLED)..." "Cyan"

    if (-not (Test-Path $IosRoot)) {
        Say ("[WARN] iOS project root not found at {0}. Skipping iOS step." -f $IosRoot) "DarkYellow"
    } else {
        Say "[INFO] iOS upload usually requires macOS + Xcode. This is a placeholder for CI pipeline." "Gray"
        Invoke-AppleStoreConnectUploadSim -IPAPath "<your-ipa-path-here>"
    }
} else {
    Say "`n[STEP 6] iOS / App Store auto-publish is DISABLED (EnableAppStorePublish = `$false)." "Gray"
}

# =============================================================================
# STEP 7 — Package deliverables into ZIP
# =============================================================================
Say "`n[STEP 7] Creating client deliverable ZIP..." "Cyan"

New-Item -ItemType Directory -Path $DeliverableRoot -Force | Out-Null

$TmpBundle = Join-Path $DeliverableRoot ("{0}_bundle_{1}" -f $Project, $Timestamp)
New-Item -ItemType Directory -Path $TmpBundle -Force | Out-Null

if (Test-Path $AppRoot) {
    Copy-Item -Path $AppRoot -Destination (Join-Path $TmpBundle "src") -Recurse -Force
}
if (Test-Path $SiteProject) {
    Copy-Item -Path $SiteProject -Destination (Join-Path $TmpBundle "deployed_web") -Recurse -Force
}

$ReadmePath = Join-Path $TmpBundle "README.txt"
$readmeContent = @"
NIFDU Generated Product: $Project
Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Web URL (internal): http://127.0.0.1/apps/$Project/
Domain (if wired): $TargetDomain

Contents:
 - src\          : Source code (web + mobile) produced by NIFDU Agent 3
 - deployed_web\ : Files deployed to NIFDU's webroot for this project

Use this ZIP for clients, store submissions, or external deployments.
"@
Set-Content -LiteralPath $ReadmePath -Value $readmeContent -Encoding UTF8

if (Test-Path $DeliverableZip) {
    Remove-Item $DeliverableZip -Force
}
Compress-Archive -Path (Join-Path $TmpBundle "*") -DestinationPath $DeliverableZip -Force

Say ("[OK] Deliverable ZIP created: {0}" -f $DeliverableZip) "Green"
Invoke-SendEmailSim -File $DeliverableZip

Say "`n=== NIFDU AGENT 3 ONE-SHOT PIPELINE COMPLETED ===`n" "Yellow"
