# ==========================================================
# C:\nifdu\ops\nifdu_agent3_use_all_apis.ps1
# NIFDU AGENT 3 - MAKE ALL RELEVANT APIs GET USED
# ----------------------------------------------------------
# This script runs multiple Agent 3 fullstack autoloops.
# Each project is an "API Lab" React app that MUST:
#   - Call real NIFDU APIs via fetch(...)
#   - Render the JSON / status on screen
#   - Handle errors gracefully (show error boxes)
#
# Labs:
#   1) Core / Health / Log
#   2) AI / Chat / Codegen / Vibe
#   3) Truth / Compile / Run
#   4) AV (plan/render/control/sprite)
#   5) RAG / RL / Train
#   6) Retail / Lead / Projects / Auth / Proxy / Deploy
# ==========================================================

param(
    [string]$BaseUrl = "http://127.0.0.1",
    [int]   $MaxCyclesPerLab = 3
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

# Path to your existing fullstack autoloop
$AutoLoop = "C:\nifdu\ops\nifdu_agent3_fullstack_autoloop.ps1"

Say "`n=== NIFDU AGENT 3 - USE ALL APIs (MASTER LAB RUN) ===`n" "Yellow"

if (!(Test-Path $AutoLoop)) {
    Say "[FATAL] Auto-loop script not found: $AutoLoop" "Red"
    exit 1
}

# ----------------------------------------------------------
# Define all API labs (projects) and the prompts for Agent 3
# ----------------------------------------------------------
$Labs = @()

# 1) CORE / HEALTH / LOG
$Labs += @{
    Project    = "nifdu_api_lab_core"
    Stack      = "react"
    ExpectText = "NIFDU API Lab - Core"
    Prompt     = @"
You are NIFDU Agent 3.

Build a React + Vite (+ Tailwind if helpful) dashboard called:
  "NIFDU API Lab - Core"

GOAL:
Use and visually demonstrate the following NIFDU APIs from the browser,
calling them via fetch() from the React app and rendering the results:

- GET  http://127.0.0.1/health
- GET  http://127.0.0.1/api/health
- GET  http://127.0.0.1/api/ping        (if available)
- GET  http://127.0.0.1/api/db_health   (if available)
- GET  http://127.0.0.1/api/log         (stream NIFDU log buffer)
- GET  http://127.0.0.1/api/list        (if available)

REQUIREMENTS:

- Dark-ish theme dashboard layout.
- Left side: list of API buttons (Health, Ping, DB Health, Log, etc.).
- Right side: a "Result" panel showing:
    - HTTP status code
    - URL that was called
    - prettified JSON / text response
- Show loading state and error state.
- If an endpoint 404/500s, DO NOT crash: show a red error box with the message.
- Put the text "NIFDU API Lab - Core" clearly at top of the UI.
"@
}

# 2) AI / CHAT / CODEGEN / VIBE
$Labs += @{
    Project    = "nifdu_api_lab_ai"
    Stack      = "react"
    ExpectText = "NIFDU API Lab - AI"
    Prompt     = @"
You are NIFDU Agent 3.

Build a React + Vite (+ Tailwind if helpful) app:
  "NIFDU API Lab - AI"

GOAL:
Use these AI-related NIFDU APIs from the browser:

- POST http://127.0.0.1/api/chat
- POST http://127.0.0.1/api/ai/complete        (if available)
- POST http://127.0.0.1/api/codegen            (safe JSON stub usage)
- POST http://127.0.0.1/api/vibe               (if available)
- GET  http://127.0.0.1/api/behavior_test      (if available)

UI REQUIREMENTS:

- Layout:
    - Left panel: text area for the user prompt.
    - Middle: buttons "Send to /api/chat", "Send to /api/ai/complete", "Test /api/vibe".
    - Right: scrollable JSON viewer of the last response.
- For /api/chat and /api/ai/complete:
    - Send JSON with at least a "prompt" field using the text area content.
- For /api/codegen:
    - Send a small JSON stub like:
      { "project": "sample_project", "prompt": "say hello", "brain": "auto", "mode": "vibe_coding" }
    - Show response JSON in the viewer.
- Show the text "NIFDU API Lab - AI" clearly at the top.
- Handle errors gracefully and show them in a red box.
"@
}

# 3) TRUTH / COMPILE / RUN
$Labs += @{
    Project    = "nifdu_api_lab_truth"
    Stack      = "react"
    ExpectText = "NIFDU API Lab - Truth"
    Prompt     = @"
You are NIFDU Agent 3.

Build a React + Vite app called:
  "NIFDU API Lab - Truth Engine"

GOAL:
Use the compiler / truth APIs:

- POST http://127.0.0.1/api/truth
- POST http://127.0.0.1/api/compile       (if available)
- POST http://127.0.0.1/api/run           (if available)

UI REQUIREMENTS:

- Show the text "NIFDU API Lab - Truth" prominently.
- Input box where user can type a C++-style boolean expression, e.g.:
    1 + 1 == 2
- Button "Verify with /api/truth":
    - POST JSON: { "expression": "<userExpression>" }
    - Show returned fields (compiled, exit, output, etc.) in a result panel.
- Optional: panels/buttons for /api/compile and /api/run, sending simple code snippets.
- If /api/truth or others are unreachable, catch fetch errors and show readable messages
  in a red warning box instead of crashing.
"@
}

# 4) AV (plan/render/control/sprite)
$Labs += @{
    Project    = "nifdu_api_lab_av"
    Stack      = "react"
    ExpectText = "NIFDU API Lab - AV"
    Prompt     = @"
You are NIFDU Agent 3.

Build a React + Vite app:
  "NIFDU API Lab - AV Studio"

GOAL:
Use the AV-related NIFDU APIs:

- POST http://127.0.0.1/api/av/plan
- POST http://127.0.0.1/api/av/render       (if available)
- POST http://127.0.0.1/api/av/control      (if available)
- POST http://127.0.0.1/api/av/sprite

UI REQUIREMENTS:

- Dark studio layout.
- Text area for a natural language AV prompt (e.g. "cat in the rain moving right").
- Buttons:
    - "Plan" -> POST to /api/av/plan with JSON { "prompt": "<textArea>" } or raw text body
    - "Sprite" -> POST to /api/av/sprite with basic JSON
    - Optionally "Render" and "Control" buttons if you can reason about their payloads.
- Show returned JSON plan / sprite info in a result panel.
- Also show a small info text telling user where AV files are written
  (e.g. media/generated/av_control.json or av_latest.*), based on the API responses.
- Title at top: "NIFDU API Lab - AV".
- Handle unreachable endpoints with clear error messages, not crashes.
"@
}

# 5) RAG / RL / Train
$Labs += @{
    Project    = "nifdu_api_lab_rag"
    Stack      = "react"
    ExpectText = "NIFDU API Lab - RAG"
    Prompt     = @"
You are NIFDU Agent 3.

Build a React + Vite app:
  "NIFDU API Lab - RAG & RL"

GOAL:
Exercise the learning-related APIs:

- POST http://127.0.0.1/api/rag           (query / retrieval)
- POST http://127.0.0.1/api/rl            (reinforcement feedback)
- POST http://127.0.0.1/api/train         (training data)

UI REQUIREMENTS:

- Title: "NIFDU API Lab - RAG & RL".
- Simple 3-tab layout:
    1) RAG Query
        - Input box: "question"
        - Button posts JSON to /api/rag (e.g. { "query": "<text>" })
        - Show returned context / answer JSON.
    2) RL Feedback
        - Input for "episode" or "responseId"
        - Buttons "Reward" and "Punish" posting to /api/rl with reward scores.
    3) Train
        - Form to post small training pairs (question, answer) to /api/train.
- All calls must use fetch(), display status code + parsed JSON, and handle errors nicely.
"@
}

# 6) Retail / Lead / Projects / Auth / Proxy / Deploy
$Labs += @{
    Project    = "nifdu_api_lab_retail"
    Stack      = "react"
    ExpectText = "NIFDU API Lab - Retail"
    Prompt     = @"
You are NIFDU Agent 3.

Build a React + Vite app:
  "NIFDU API Lab - Retail & Ops"

GOAL:
Use business-facing and ops APIs:

- GET/POST http://127.0.0.1/api/retail/blueprints
- POST     http://127.0.0.1/api/lead
- POST     http://127.0.0.1/api/project
- POST     http://127.0.0.1/api/projects/accept
- POST     http://127.0.0.1/api/auth/generate_key      (if available)
- GET/POST http://127.0.0.1/api/proxy/config           (if available)
- GET      http://127.0.0.1/api/proxy/routes           (if available)
- GET      http://127.0.0.1/api/proxy/services         (if available)
- POST     http://127.0.0.1/api/proxy/reload           (if available)
- POST     http://127.0.0.1/api/deploy                 (if available)

UI REQUIREMENTS:

- Title: "NIFDU API Lab - Retail & Ops".
- Split layout:
    - "Retail Blueprints" panel:
        - Button to fetch /api/retail/blueprints and render cards for each blueprint.
    - "Leads & Projects" panel:
        - Simple form (name, email, interest) posting to /api/lead.
        - Form to create a project via /api/project.
        - Button to accept a sample project via /api/projects/accept.
    - "Ops / Proxy / Deploy" panel:
        - Buttons to view /api/proxy/routes and /api/proxy/services.
        - Button to call /api/auth/generate_key and show the key.
        - Button to call /api/deploy with a small stub JSON.
- All API calls MUST actually hit those URLs with fetch(), not just fake text.
- Show status code + JSON for each call, with error messages in case of failure.
"@
}

# ----------------------------------------------------------
# Master loop: run all labs
# ----------------------------------------------------------
foreach ($lab in $Labs) {
    $proj   = $lab.Project
    $stack  = $lab.Stack
    $prompt = $lab.Prompt
    $expect = $lab.ExpectText

    Say "`n==================================================" "Cyan"
    Say ("=== NIFDU API LAB: {0} ===" -f $proj) "Cyan"
    Say ("Stack    : {0}" -f $stack) "Gray"
    Say ("Expect   : {0}" -f $expect) "Gray"
    Say ("BaseUrl  : {0}" -f $BaseUrl) "Gray"
    Say "==================================================`n" "Cyan"

    powershell -ExecutionPolicy Bypass `
        -File $AutoLoop `
        -Project $proj `
        -Prompt  $prompt `
        -Stack   $stack `
        -ExpectText $expect `
        -BaseUrl $BaseUrl `
        -MaxCycles $MaxCyclesPerLab
}

Say "`n=== NIFDU API LAB MASTER RUN COMPLETE ===`n" "Green"
