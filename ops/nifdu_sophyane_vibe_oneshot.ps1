# ==============================================
# C:\nifdu\ops\nifdu_sophyane_vibe_oneshot.ps1
# NIFDU / SOPHYANE.COM — VIBE CODING ONE-SHOT
# ==============================================

[CmdletBinding()]
param(
    [string]$ProjectName = "sophyane_vibe_coding",
    [string]$HostName    = "sophyane.com"
)

$ErrorActionPreference = "Stop"
$Global:NifduBaseUrl = "http://127.0.0.1"   # Will be updated after detection

# ---------------------------
# UTILITIES
# ---------------------------
function Say {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Message -ForegroundColor $Color
    } catch {
        Write-Host $Message
    }
}

function Die {
    param([string]$Message)
    Write-Host ""
    Write-Host "FATAL: $Message" -ForegroundColor Red
    throw $Message
}

function Load-DotEnvFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        Die "Missing env file: $Path"
    }

    Say "Loading env from $Path" "DarkCyan"

    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        if ($line.StartsWith("#")) { return }

        $idx = $line.IndexOf("=")
        if ($idx -le 0) { return }

        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()

        # Strip surrounding quotes if any
        if ($val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Substring(1, $val.Length - 2)
        } elseif ($val.StartsWith("'") -and $val.EndsWith("'")) {
            $val = $val.Substring(1, $val.Length - 2)
        }

        [Environment]::SetEnvironmentVariable($key, $val, "Process")
    }
}

function Invoke-NifduApi {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $false)]$BodyObject
    )

    $uri = "$Global:NifduBaseUrl$Path"
    $jsonBody = $null

    if ($BodyObject) {
        $jsonBody = $BodyObject | ConvertTo-Json -Depth 20
    }

    Say ">>> $Method $uri" "DarkGray"

    try {
        if ($Method -eq "GET") {
            return Invoke-RestMethod -Uri $uri -Method GET -ContentType "application/json; charset=utf-8"
        } else {
            return Invoke-RestMethod -Uri $uri -Method $Method -Body $jsonBody -ContentType "application/json; charset=utf-8"
        }
    } catch {
        Die "NIFDU API call to $uri failed: $($_.Exception.Message)"
    }
}

function Start-NifduMonolith {
    Say "`n=== AUTO-START NIFDU MONOLITH (BUILD + RUN) ===" "Yellow"

    $buildDir = "C:\nifdu\build"
    $exePath  = "C:\nifdu\build\Release\nifdu.exe"

    if (-not (Test-Path $buildDir)) {
        Die "Build directory not found: $buildDir"
    }

    Push-Location $buildDir
    try {
        Say "Building NIFDU (cmake --build . --config Release)..." "DarkCyan"
        cmake --build . --config Release | Out-Null
    } catch {
        Pop-Location
        Die "Build failed: $($_.Exception.Message)"
    }
    Pop-Location

    Say "Stopping any existing nifdu.exe..." "DarkCyan"
    try {
        Stop-Process -Name nifdu -Force -ErrorAction SilentlyContinue
    } catch {}

    if (-not (Test-Path $exePath)) {
        Die "nifdu.exe not found at $exePath after build."
    }

    Say "Starting nifdu.exe from $exePath" "DarkCyan"
    Start-Process $exePath | Out-Null
}

function Test-NifduPort {
    param(
        [int]$Port
    )

    if ($Port -eq 80) {
        $url = "http://127.0.0.1/api/"
    } else {
        $url = "http://127.0.0.1:$Port/api/"
    }

    try {
        $res = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing -ErrorAction Stop
        $code = [int]$res.StatusCode
        Say "Health probe on $url returned HTTP $code" "DarkGreen"
        return $true
    } catch {
        $ex = $_.Exception
        $we = $ex -as [System.Net.WebException]
        if ($we -and $we.Response) {
            try {
                $statusCode = [int]$we.Response.StatusCode
                Say "Health probe on $url got HTTP $statusCode" "DarkYellow"
                # Treat any HTTP-level response (2xx–4xx) as "port is alive"
                if ($statusCode -ge 200 -and $statusCode -lt 500) {
                    return $true
                }
            } catch {
                # fall through
            }
        } else {
            Say "Health probe on $url failed: $($ex.Message)" "DarkYellow"
        }
        return $false
    }
}

function Wait-ForNifduHealth {
    param(
        [int]$Retries = 30,
        [int]$DelaySeconds = 2,
        [int[]]$Ports = @(80, 8000)
    )

    for ($i = 1; $i -le $Retries; $i++) {
        foreach ($port in $Ports) {
            if (Test-NifduPort -Port $port) {
                if ($port -eq 80) {
                    $Global:NifduBaseUrl = "http://127.0.0.1"
                } else {
                    $Global:NifduBaseUrl = "http://127.0.0.1:$port"
                }
                Say "NIFDU detected alive on port $port, base URL = $Global:NifduBaseUrl" "Green"
                return
            }
        }
        Say "Waiting for NIFDU to become responsive... attempt $i/$Retries" "DarkYellow"
        Start-Sleep -Seconds $DelaySeconds
    }

    Die "NIFDU not responding on ports $($Ports -join ', ') after $Retries attempts."
}

# ---------------------------
# STEP 1 — LOAD ENVS
# ---------------------------
Say "`n=== NIFDU / SOPHYANE VIBE ONE-SHOT ===`n" "Yellow"

$mainEnvPath     = "C:\ENV\.env"
$godaddyEnvPath  = "C:\ENV\godaddy_sophyane.env"

Load-DotEnvFile -Path $mainEnvPath
Load-DotEnvFile -Path $godaddyEnvPath

# Sanity check on key vars (do NOT print secrets)
$pgHost = $env:PGHOST_SOPHYANE_COM
$pgPort = $env:PGPORT_SOPHYANE_COM
$pgDb   = $env:PGDATABASE_SOPHYANE_COM
$gdKey  = $env:GODADDY_API_KEY
$gdSec  = $env:GODADDY_API_SECRET

if (-not $pgHost -or -not $pgPort -or -not $pgDb) {
    Die "sophyane_com_db env vars not fully set (PGHOST_SOPHYANE_COM / PGPORT_SOPHYANE_COM / PGDATABASE_SOPHYANE_COM)."
}
if (-not $gdKey -or -not $gdSec) {
    Die "GoDaddy env vars not fully set (GODADDY_API_KEY / GODADDY_API_SECRET)."
}

Say ("Postgres target: {0}:{1} / {2}" -f $pgHost, $pgPort, $pgDb) "Green"
Say "GoDaddy API: present (key/secret loaded)" "Green"

# ---------------------------
# STEP 2 — ENSURE NIFDU UP (ANY PORT)
# ---------------------------
Say "`nEnsuring NIFDU monolith is running..." "Yellow"
Start-NifduMonolith
Wait-ForNifduHealth -Retries 30 -DelaySeconds 2 -Ports @(80, 8000)
Say ("Using NIFDU base URL: {0}" -f $Global:NifduBaseUrl) "Cyan"

# ---------------------------
# STEP 3 — PREP FOLDERS
# ---------------------------
$rootAppsDir = "C:\webroot\nifdu.com\www\apps"
$sophyaneDir = Join-Path $rootAppsDir "sophyane"
$logDir      = "C:\sophyane\logs"

foreach ($d in @($rootAppsDir, $sophyaneDir, $logDir)) {
    if (-not (Test-Path $d)) {
        Say "Creating directory: $d" "DarkCyan"
        New-Item -ItemType Directory -Path $d | Out-Null
    }
}

# ---------------------------
# STEP 4 — BIG AGENT 3 PROMPT
# ---------------------------
$agentPrompt = @"
You are NIFDU Agent 3, building the **flagship vibe-coding experience** for https://$HostName.

PROJECT NAME:
- $ProjectName

STATIC FRONTEND TARGET:
- Root directory:
    C:/webroot/nifdu.com/www/apps/sophyane
- The app will be served via NIFDU HTTP80 router under:
    GET /apps/sophyane/...

OVERALL GOAL:
- Make Sophyane.com the **most user-friendly vibe-coding website in the world**, comparable to or better than Replit Agent 3, Cursor, etc., but powered entirely by NIFDU.
- Focus on **clarity, trust, transparency, and control** for the user.

CORE EXPERIENCE (VERY IMPORTANT):
1. Chat with "Sophyane" while coding:
   - The user chats with an AI called **Sophyane**.
   - Sophyane builds full projects using NIFDU’s 38 APIs.
   - The user can:
       * Start with a high-level idea.
       * See a plan and a file tree.
       * Watch the preview update.
       * Interrupt mid-process to give new instructions.
       * Refine after preview ("change color", "add auth", "add new page").
   - This is a **continuous loop**:
       PLAN → GENERATE → PREVIEW → FEEDBACK → MODIFY → PREVIEW → DEPLOY.

2. Layout / UI:
   - Modern, dark, minimal, professional design.
   - Good UX on both desktop and laptop screens.
   - Layout suggestion:
       * Left: Chat panel with Sophyane (conversation history).
       * Center: Live Preview iframe / pane showing current running app or page.
       * Right: File system / project explorer + inspectors.
   - The user can:
       * Click files to see code (read-only viewer is OK; basic editing optional).
       * See which files were recently changed.
       * See logs / status of last generation.
   - Prominent "Run" / "Update Preview" button to re-sync preview with latest code.

3. Storage / Project options:
   - At project-level, user chooses:
       a) "Save in Sophyane Cloud"
           - Means: store all project metadata in sophyane_com_db
             and keep files in a structured folder on this device.
       b) "Download to my device"
           - Export a ZIP of the current project that user can download.
   - You must implement:
       - A clear UI toggle between modes.
       - For cloud mode: show a list of the user's projects, open, rename, delete.
       - For download: a simple "Export ZIP" button that hits an API.

4. Auth & Identity:
   - Use **Supabase authentication** for frontend session auth.
   - Support:
       * Email + password
       * Google OAuth
       * GitHub OAuth
   - Keep the frontend purely static (no Node build-time auth).
   - Use Supabase JS client via CDN and environment variables accessible
     on the frontend (e.g., public anon key, project URL).
   - After login, the app:
       * Shows the user's identity (avatar/name/email).
       * Stores project ownership against this user in sophyane_com_db.

DATABASE BACKEND: sophyane_com_db (Postgres)
------------------------------------------------
Use these ENV VARS:

- PGHOST_SOPHYANE_COM
- PGPORT_SOPHYANE_COM
- PGUSER_SOPHYANE_COM
- PGPASSWORD_SOPHYANE_COM
- PGDATABASE_SOPHYANE_COM

Design a simple, robust schema (you may output as SQL files) to track:

1) users
   - id (UUID / bigserial)
   - supabase_user_id (if using Supabase auth)
   - email
   - display_name
   - created_at
   - last_seen_at

2) projects
   - id
   - user_id (FK -> users)
   - name
   - description
   - mode (cloud|download)
   - root_path (local path on disk, e.g. under C:/sophyane/projects/<id>)
   - created_at
   - updated_at

3) sessions (chat sessions)
   - id
   - project_id
   - supyane_conversation_log (JSON)
   - last_prompt
   - last_response
   - created_at
   - updated_at

4) usage / billing
   - id
   - user_id
   - project_id
   - session_id
   - nifdu_api (which endpoint was used)
   - tokens_in
   - tokens_out
   - base_cost_usd
   - premium_cost_usd   (IMPORTANT: 100% premium)
   - created_at

Important business rule:
- "premium_cost_usd" = "base_cost_usd * 2.0"

5) domains
   - id
   - user_id
   - project_id
   - domain_name
   - provider ("GoDaddy")
   - status ("searching", "available", "purchased", "dns_configured", "failed")
   - dns_records (JSON)
   - created_at
   - updated_at

The actual SQL DDL can live in:
  C:/sophyane/db/schema_sophyane.sql

NIFDU APIs (38 endpoints — USE THEM INTELLIGENTLY)
---------------------------------------------------
Use /api/chat, /api/codegen, /api/compile, /api/deploy, /api/truth, /api/rag, /api/ai/*, /api/retail/blueprints, /api/av/*, /api/rl, /api/log, /api/list, /api/project, /api/projects/accept, /api/proxy/*, etc. in a way that gives the best experience.

GoDaddy API INTEGRATION
------------------------
ENV Vars:
- GODADDY_API_KEY
- GODADDY_API_SECRET

Expose NIFDU endpoints under /api/sophyane/domains for search, purchase, and configure_dns, calling GoDaddy REST API internally and storing domain state in sophyane_com_db.

CHAT LOOP
---------
Implement full PLAN → GENERATE → PREVIEW → FEEDBACK → MODIFY → PREVIEW → DEPLOY loop as described.

DELIVERABLES
------------
Create at least:
- C:/webroot/nifdu.com/www/apps/sophyane/index.html
- C:/webroot/nifdu.com/www/apps/sophyane/js/app.js
- C:/webroot/nifdu.com/www/apps/sophyane/css/styles.css
- C:/sophyane/db/schema_sophyane.sql
- C:/sophyane/docs/ARCHITECTURE.md
- C:/sophyane/docs/API_SOPHYANE.md
- C:/sophyane/docs/DB_SCHEMA.md
- Optional: C:/nifdu/src/sophyane_backend/* for GoDaddy + usage tracking.
"@

# ---------------------------
# STEP 5 — CALL /api/chat (Agent 3, vibe_coding)
# ---------------------------
Say "`nSending one-shot Sophyane spec to NIFDU Agent 3..." "Yellow"

$body = @{
    project = $ProjectName
    prompt  = $agentPrompt
    brain   = "auto"
    mode    = "vibe_coding"
}

$response = Invoke-NifduApi -Path "/api/chat" -Method "POST" -BodyObject $body

# ---------------------------
# STEP 6 — LOG RESPONSE
# ---------------------------
$timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir      = "C:\sophyane\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logFileJson = Join-Path $logDir "sophyane_agent3_response_$timestamp.json"

try {
    $response | ConvertTo-Json -Depth 20 | Out-File -FilePath $logFileJson -Encoding UTF8
    Say "Agent 3 raw response logged to: $logFileJson" "DarkGreen"
} catch {
    Say "Warning: could not log Agent 3 response: $($_.Exception.Message)" "DarkYellow"
}

Say "`n=== DONE ===" "Green"
Say "Next steps:" "Cyan"
Say " - Check the generated frontend at: C:/webroot/nifdu.com/www/apps/sophyane" "Gray"
Say " - Visit: https://$HostName/apps/sophyane (through your TLS / proxy)" "Gray"
Say " - Review docs under: C:/sophyane/docs" "Gray"
Say " - Apply DB schema if needed: C:/sophyane/db/schema_sophyane.sql" "Gray"
