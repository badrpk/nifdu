# === NIFDU: UI PORT GOVERNOR INJECTION (auto) ===
$__NIFDU_OPS = "C:\nifdu\ops"
$__NIFDU_FREE = Join-Path $__NIFDU_OPS "free_port.ps1"
if(Test-Path $__NIFDU_FREE){
  try{
    powershell -ExecutionPolicy Bypass -File $__NIFDU_FREE -Port 3000 | Out-Host
  } catch {
    Write-Host ("[WARN] free_port.ps1 failed: " + $_.Exception.Message)
  }
}
$env:PORT = "3000"
# === END NIFDU INJECTION ===
# ==============================================
# C:\nifdu\ops\nifdu_sophyane_fullstack_oneshot.ps1
# NIFDU / SOPHYANE — FULLSTACK VIBE-CODING ONE-SHOT
# ----------------------------------------------
# Goal:
#   - Use NIFDU Agent 3 (/api/codegen) to build the full Sophyane
#     vibe-coding website for sophyane.com.
#   - Project root: C:/nifdu/src/apps/sophyane_live
#   - Stack: Next.js (app router), TypeScript, Tailwind, pnpm.
#   - Loop:
#       /api/codegen -> write files -> pnpm install/build ->
#       capture errors -> send back to Agent 3 -> repeat.
#
# Usage:
#   cd C:\nifdu\ops
#   powershell -ExecutionPolicy Bypass `
#     -File .\nifdu_sophyane_fullstack_oneshot.ps1
#
# Assumptions:
#   - nifdu.exe is running or can be built at C:\nifdu\build\Release\nifdu.exe
#   - NIFDU HTTP stack is on http://127.0.0.1:8000
#   - pnpm and Node.js are installed and on PATH.
#   - C:\ENV\.env and C:\ENV\godaddy_sophyane.env exist (optional but preferred).
# ==============================================

param(
    [string]$BaseUrl   = "http://127.0.0.1:8000",
    [string]$ProjectId = "sophyane_live",
    [string]$AppRoot   = "C:/nifdu/src/apps/sophyane_live",
    [int]$MaxIterations = 3
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
        Write-Host $Message -ForegroundColor $Color
    } catch {
        Write-Host $Message
    }
}

function Load-EnvFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Say "Env file not found: $Path" "DarkGray"
        return
    }
    Say "Loading env from $Path" "DarkGray"
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*#') { return }
        if ($_ -match '^\s*$') { return }
        $parts = $_ -split '=', 2
        if ($parts.Count -eq 2) {
            $name  = $parts[0].Trim()
            $value = $parts[1].Trim().Trim('"')
            if ($name) {
                [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
    }
}

Clear-Host
Say "=== NIFDU / SOPHYANE — FULLSTACK VIBE-CODING ONE-SHOT ===`n" "Yellow"

# ------------------------------------------------
# 1) Load env (brain, DB, GoDaddy, etc.)
# ------------------------------------------------
Load-EnvFile "C:\ENV\.env"
Load-EnvFile "C:\ENV\godaddy_sophyane.env"

# ------------------------------------------------
# 2) Ensure NIFDU monolith is running
# ------------------------------------------------
Say "`nStep 1 — Ensuring NIFDU monolith is running..." "Cyan"

$proc = Get-Process nifdu -ErrorAction SilentlyContinue
if (-not $proc) {
    Say "No running nifdu.exe found. Building and starting monolith..." "DarkYellow"

    Push-Location "C:\nifdu\build"
    try {
        cmake --build . --config Release
        Say "Build completed (Release)." "Green"
    } catch {
        Say "Build failed. Check errors above." "Red"
        Pop-Location
        exit 1
    }
    Pop-Location

    $exePath = "C:\nifdu\build\Release\nifdu.exe"
    if (-not (Test-Path $exePath)) {
        Say "❌ nifdu.exe not found at $exePath" "Red"
        exit 1
    }

    $p = Start-Process -FilePath $exePath -PassThru
    Say "Started nifdu.exe (PID: $($p.Id)). Waiting a bit for boot..." "Green"
    Start-Sleep -Seconds 3
} else {
    $first = $proc | Select-Object -First 1
    Say ("nifdu.exe already running (PID: {0})." -f $first.Id) "Green"
}

# ------------------------------------------------
# 3) Prepare project root
# ------------------------------------------------
Say "`nStep 2 — Preparing Sophyane project root at $AppRoot ..." "Cyan"

if (-not (Test-Path $AppRoot)) {
    Say "Creating app root directory..." "DarkYellow"
    New-Item -ItemType Directory -Force -Path $AppRoot | Out-Null
} else {
    Say "App root already exists." "DarkGray"
}

# ------------------------------------------------
# 4) Agent 3 loop: /api/codegen -> write files -> pnpm build
# ------------------------------------------------
Say "`nStep 3 — Running Agent 3 loop via /api/codegen (max $MaxIterations iterations)..." "Cyan"

$errorText = ""
$installDone = $false

for ($i = 1; $i -le $MaxIterations; $i++) {
    Say "`n=== AGENT 3 ITERATION #$i ===" "Magenta"

    $promptLines = @()
    $promptLines += @"
You are NIFDU Agent 3, building the full-stack Sophyane vibe-coding website for the domain sophyane.com.

GOAL:
- Create a production-grade app under:
    C:/nifdu/src/apps/sophyane_live

STACK:
- Next.js (latest, app router), TypeScript, Tailwind CSS, pnpm.
- Do NOT use deprecated experimental.appDir flags in next.config.js.
- Use pnpm as the package manager.
- Aim for a clean, modern dark theme with green accents (to match NIFDU).

PAGES & UX:
1) "/"  (Landing)
   - Explain in simple language what Sophyane + NIFDU is.
   - Highlight that it is a self-hosted AI factory with 38+ APIs.
   - Clear CTA button: "Open Vibe Coding Studio".

2) "/studio" (Vibe Coding Studio)
   - 3-column layout:
       - Left: Chat panel ("Talk to Sophyane") where user types instructions.
         * For now, send requests to a local API route /api/sophyane/chat
           which will act as a thin proxy to NIFDU /api/chat or /api/codegen.
         * Create the API route handler, but you can stub actual HTTP calls if needed.
       - Center: File list + simple file preview.
         * Show files under this project root (or a mock list).
         * When a file is clicked, show its content in a read-only code viewer.
       - Right: "Preview / Status" panel.
         * Show status of last Agent 3 run.
         * Show instructions like "Run node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev in terminal to see live preview".

3) "/account" (Account / Billing placeholder)
   - Describe that Sophyane will manage users, tokens, and billing.
   - Pull configuration from environment variables where appropriate:
       PGHOST_SOPHYANE_COM, PGPORT_SOPHYANE_COM, PGUSER_SOPHYANE_COM,
       PGPASSWORD_SOPHYANE_COM, PGDATABASE_SOPHYANE_COM
   - No real DB queries yet; just a placeholder and config display.

INTEGRATIONS (STUB-FRIENDLY):
- Backend brain is NIFDU monolith on $BaseUrl.
- For now, you can:
    * Implement /app/api/sophyane/chat/route.ts (or similar) as a handler that constructs
      a JSON request to $BaseUrl/api/chat or $BaseUrl/api/codegen and logs the plan.
    * It is OK to stub the actual HTTP POST with TODOs if needed.
- Prepare a clear place in code where future GoDaddy + token billing logic will plug in.

PROJECT STRUCTURE:
- Use the app router (app/) with TypeScript.
- Include:
    - next.config.js (no deprecated experimental.appDir).
    - tailwind.config.ts, postcss.config.js.
    - app/layout.tsx, app/page.tsx (landing).
    - app/studio/page.tsx
    - app/account/page.tsx
    - app/api/sophyane/chat/route.ts (or equivalent for Next 15/16).
    - A small README.md that explains how to:
        * Install: pnpm install
        * Dev: node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev
        * Build: pnpm build

CONSTRAINTS:
- Paths MUST be absolute and Windows-safe, under:
    C:/nifdu/src/apps/sophyane_live
- Only use Node/React/Next/TypeScript for the frontend project; the hosting runtime is NIFDU.
- Do not introduce Docker or external cloud dependencies.

RETURN FORMAT (VERY IMPORTANT):
- Respond with JSON like:
  {
    "engine": "openai",
    "files": [
      {
        "action": "write",
        "path": "C:/nifdu/src/apps/sophyane_live/...",
        "content": "... file contents ...",
        "language": "typescript" | "javascript" | "json" | "markdown" | "text"
      },
      ...
    ]
  }

"@

    if ($errorText) {
        $promptLines += "`nPrevious pnpm build/install error log (truncated):`n"
        $promptLines += $errorText
        $promptLines += "`nPlease fix the errors and update the necessary files."
    }

    $body = @{
        project = $ProjectId
        brain   = "auto"
        mode    = "vibe_coding"
        prompt  = ($promptLines -join "`n")
    }

    $json = $body | ConvertTo-Json -Depth 10
    Say "Calling /api/codegen on $BaseUrl ..." "Cyan"
    $resp = Invoke-RestMethod `
        -Uri "$BaseUrl/api/codegen" `
        -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Body $json

    if (-not $resp) {
        Say "Empty response from /api/codegen." "Red"
        break
    }

    if ($resp.files) {
        Say "Writing files from Agent 3 response..." "Cyan"
        foreach ($f in $resp.files) {
            $action  = $f.action
            $path    = $f.path
            $content = $f.content

            if (-not $path) { continue }

            $dir = Split-Path $path -Parent
            if ($dir -and -not (Test-Path $dir)) {
                New-Item -ItemType Directory -Force -Path $dir | Out-Null
            }

            switch ($action) {
                "write" {
                    $content | Set-Content -Path $path -Encoding UTF8
                    Say ("  [write]  {0}" -f $path) "DarkGray"
                }
                "append" {
                    $content | Add-Content -Path $path -Encoding UTF8
                    Say ("  [append] {0}" -f $path) "DarkGray"
                }
                default {
                    $content | Set-Content -Path $path -Encoding UTF8
                    Say ("  [write*] {0}" -f $path) "DarkGray"
                }
            }
        }
    } else {
        Say "No files[] field in response; nothing to write." "DarkYellow"
    }

    # --------------------------------------------
    # pnpm install (once)
    # --------------------------------------------
    if (-not $installDone) {
        if (-not (Test-Path (Join-Path $AppRoot "package.json"))) {
            Say "WARNING: package.json not found yet under $AppRoot. Agent 3 may need another iteration." "DarkYellow"
        } else {
            Say "`nRunning pnpm install (first time only)..." "Cyan"
            Push-Location $AppRoot
            $installOutput = & pnpm install 2>&1
            $installExit = $LASTEXITCODE
            Pop-Location

            if ($installExit -ne 0) {
                Say "pnpm install failed with exit code $installExit. Feeding error back to Agent 3..." "Red"
                $errorText = ($installOutput | Out-String)
                # Trim errorText to avoid huge payloads
                if ($errorText.Length -gt 4000) {
                    $errorText = $errorText.Substring(0, 4000) + "`n...[truncated]..."
                }
                continue
            } else {
                Say "pnpm install completed successfully." "Green"
                $installDone = $true
            }
        }
    }

    # --------------------------------------------
    # pnpm build (truth test)
    # --------------------------------------------
    Say "`nRunning pnpm build to test project..." "Cyan"
    Push-Location $AppRoot
    $buildOutput = & pnpm build 2>&1
    $buildExit = $LASTEXITCODE
    Pop-Location

    if ($buildExit -eq 0) {
        Say "✅ pnpm build succeeded. Sophyane app compiles cleanly." "Green"
        $errorText = ""
        break
    } else {
        Say "pnpm build failed with exit code $buildExit. Feeding error back to Agent 3..." "DarkYellow"
        $errorText = ($buildOutput | Out-String)
        if ($errorText.Length -gt 4000) {
            $errorText = $errorText.Substring(0, 4000) + "`n...[truncated]..."
        }
    }
}

Say "`n=== DONE ===" "Yellow"
Say "Project root: $AppRoot" "Gray"
Say "Next steps (manual):" "DarkGray"
Say "  1) cd $AppRoot" "DarkGray"
Say "  2) node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev" "DarkGray"
Say "  3) Open your browser to the dev URL and wire sophyane.com via Caddy/NIFDU proxy as needed." "DarkGray"
