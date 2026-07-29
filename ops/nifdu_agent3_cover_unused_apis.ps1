# ==============================================
# C:\nifdu\ops\nifdu_agent3_cover_unused_apis.ps1
# NIFDU AGENT 3 - COVER UNUSED APIs (FRONTEND)
# ----------------------------------------------
# Uses nifdu_agent3_fullstack_autoloop.ps1 to
# generate a React app that calls all currently
# UNUSED canonical APIs.
# ==============================================

param(
    [string]$BaseUrl   = "http://127.0.0.1",
    [int]   $MaxCycles = 4
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

Say "`n=== NIFDU AGENT 3 - COVER UNUSED APIs (FRONTEND LAB) ===`n" "Yellow"
Say ("BaseUrl : {0}" -f $BaseUrl) "Gray"

# Path to existing multi-stack autoloop
$AutoLoop = "C:\nifdu\ops\nifdu_agent3_fullstack_autoloop.ps1"
if (!(Test-Path $AutoLoop)) {
    Say "[FATAL] Auto-loop script not found: $AutoLoop" "Red"
    exit 1
}

# Project details
$Project    = "nifdu_api_lab_unused"
$Stack      = "react"
$ExpectText = "NIFDU API Lab - Unused APIs"

# UNUSED ENDPOINTS (from latest full report):
#   /health
#   /api/ai/config
#   /api/ai/embed
#   /api/ai/models
#   /api/ai/recall
#   /api/av/plan
#   /api/av/sprite
#   /api/av/render
#   /api/av/control
#   /api/behavior_test
#   /api/proxy/config
#   /api/proxy/reload
#   /api/retail
#   /api/ws/prices

$Prompt = @"
You are NIFDU Agent 3.

Build a **React + Vite (+ Tailwind CSS)** dashboard called:

  "NIFDU API Lab - Unused APIs"

This app MUST exercise the following currently-unused NIFDU APIs
from the browser, using **relative URLs** (VERY IMPORTANT):

UNUSED ENDPOINTS (ALL MUST BE USED):

1) Core / health
   - GET  "/health"

2) AI extra utility endpoints
   - GET  "/api/ai/config"
   - GET  "/api/ai/models"
   - POST "/api/ai/embed"
   - POST "/api/ai/recall"

3) AV extra endpoints
   - POST "/api/av/plan"
   - POST "/api/av/sprite"
   - POST "/api/av/render"
   - POST "/api/av/control"

4) Behavior / diagnostics
   - GET  "/api/behavior_test" (or POST if needed; you can try GET first)

5) Retail / proxy / misc
   - GET  "/api/retail"
   - GET  "/api/proxy/config"
   - POST "/api/proxy/reload"
   - GET  "/api/ws/prices"

ABSOLUTELY MANDATORY FOR NIFDU SCANNER:

- In your source code, the literal strings for **every endpoint above**
  must appear exactly as written, INCLUDING the leading slash. For example:

    "/health"
    "/api/ai/config"
    "/api/ai/models"
    "/api/ai/embed"
    "/api/ai/recall"
    "/api/av/plan"
    "/api/av/sprite"
    "/api/av/render"
    "/api/av/control"
    "/api/behavior_test"
    "/api/proxy/config"
    "/api/proxy/reload"
    "/api/retail"
    "/api/ws/prices"

- Do NOT build these URLs using string concatenation like
  "/api/" + "ai/config". They must appear as full literal
  strings so the scanner finds them.

- A good pattern is to define a constant array:

    const UNUSED_ENDPOINTS = [
      "/health",
      "/api/ai/config",
      "/api/ai/models",
      "/api/ai/embed",
      "/api/ai/recall",
      "/api/av/plan",
      "/api/av/sprite",
      "/api/av/render",
      "/api/av/control",
      "/api/behavior_test",
      "/api/proxy/config",
      "/api/proxy/reload",
      "/api/retail",
      "/api/ws/prices",
    ];

  and then use these paths in your fetch() calls.

VERY IMPORTANT:

- Use **relative URLs** like "/api/ai/config", "/api/av/plan", "/health"
  instead of hard-coding "http://127.0.0.1". The app will run on the same
  origin (nifdu.com or 127.0.0.1), so fetch("/api/...") is correct.

UI REQUIREMENTS:

- Dark, clean dashboard layout using Tailwind CSS.
- Put the exact text **"NIFDU API Lab - Unused APIs"** at the top so the
  deployment health check can find it.

- Organize the UI into sections / tabs:

  1) "Core / Health"
     - Card for /health with:
       - Method + path (GET /health)
       - "Call" button
       - Result area: HTTP status, JSON/text body, and error display.

  2) "AI Extra"
     - Cards for:
       - GET /api/ai/config
       - GET /api/ai/models
       - POST /api/ai/embed
       - POST /api/ai/recall
     - Provide a minimal form where the user can type a sample text/query
       used as payload for embed/recall.
     - Show response JSON prettified.

  3) "AV Extra"
     - Textarea for a natural language AV prompt (e.g. "car moving left with rain").
     - Buttons:
         - "Plan"   -> POST to /api/av/plan with JSON like { "prompt": "<textarea value>" }
         - "Sprite" -> POST to /api/av/sprite with a simple JSON stub, e.g.
                       { "name": "demo_sprite", "frames": 10 }
         - "Render" -> POST to /api/av/render with a simple stub, e.g.
                       { "plan_id": "demo-plan-id" }
         - "Control"-> POST to /api/av/control, e.g.
                       { "action": "play", "speed": 1.0 }
     - Show the AV API responses in a result panel; also show any file paths
       returned (if the stub responses mention media file locations).

  4) "Retail / Proxy / Prices"
     - Card for GET /api/retail -> render the JSON response as key/value pairs.
     - Card for GET /api/proxy/config -> show the JSON config.
     - Card for POST /api/proxy/reload -> send a tiny stub JSON payload and
       show the result.
     - Card for GET /api/ws/prices -> show returned price data in a simple
       table (symbol, price, change, etc.), assuming the stub returns
       something like that.

  5) "Behavior Test"
     - Card for /api/behavior_test with a "Run test" button and a result
       panel for the JSON/text that comes back.

For EVERY call:

- Show a small "status" line:
    - HTTP method
    - URL path
    - status code (e.g. 200, 404, 500)
- Show response body in a scrollable, monospaced panel using JSON.stringify
  with indentation where possible.

ERROR HANDLING (MANDATORY):

- If any fetch() call fails (network error, CORS, 404, 500, invalid JSON, etc.):
  - Catch the error.
  - Show a **red error alert box** with the message.
  - Do NOT crash the React app.
- You can use a small helper hook or function to standardize API calls and
  error handling.

TECHNICAL DETAILS:

- Use Vite React setup (JS or TS is fine).
- Use functional components and hooks only (useState, useEffect).
- Prefer modern patterns:
    - Small reusable components for API cards
    - Clear typing / interfaces if you use TypeScript
- All styles can be Tailwind classes; no need for external CSS frameworks.

Remember:

- The React app will be served under something like:
    /apps/nifdu_api_lab_unused/
- All fetch() calls must be **relative** ("/api/...") to work both on
  http://127.0.0.1 and https://nifdu.com.

Finally:

- Make sure the rendered page includes the text:
    "NIFDU API Lab - Unused APIs"
  in a visible heading so the NIFDU autoloop health probe can detect it.
- And again: every endpoint path listed above MUST appear literally in
  the source code, exactly once or more.
"@

Say "`n[STEP] Calling Agent 3 fullstack autoloop for UNUSED APIs lab...`n" "Cyan"

powershell -ExecutionPolicy Bypass `
    -File $AutoLoop `
    -Project $Project `
    -Prompt  $Prompt `
    -Stack   $Stack `
    -ExpectText $ExpectText `
    -BaseUrl $BaseUrl `
    -MaxCycles $MaxCycles

Say "`n=== NIFDU AGENT 3 - UNUSED APIs LAB COMPLETE ===`n" "Green"
