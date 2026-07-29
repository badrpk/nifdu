
param(
    [string]$BaseUrl = "http://127.0.0.1:8000"
)

$ErrorActionPreference = "Stop"

Write-Host "=== NIFDU MONOLITH 38+ API STORY ONE SHOT ===" -ForegroundColor Yellow
Write-Host ""

# 1) Check if nifdu.exe process is running
$proc = Get-Process nifdu -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Host "NIFDU process (nifdu.exe) is NOT running." -ForegroundColor Red
    Write-Host "Start C:\nifdu\build\Release\nifdu.exe and run this script again." -ForegroundColor DarkRed
    return
}

Write-Host ("NIFDU is running (PID: {0}). Using BaseUrl = {1}" -f $proc.Id, $BaseUrl) -ForegroundColor Green
Write-Host ""
Write-Host "Now printing the 38+ API story in dummy founder mode..." -ForegroundColor Magenta
Write-Host ""

# 2) Short, safe story (no fancy PowerShell, just text)
Write-Host "1) WHAT IS THIS MONOLITH BRAIN?" -ForegroundColor Cyan
Write-Host "   - NIFDU is a self-hosted AI factory that lives on your machine." -ForegroundColor Gray
Write-Host "   - Inside it, 38+ APIs cover chat, codegen, compile, run, AV, deploy, proxy, DB, leads, projects, auth, and vibes." -ForegroundColor Gray
Write-Host ""

Write-Host "2) AI + CODEGEN CORE (AGENT 3 HEART)" -ForegroundColor Cyan
Write-Host "   - /api/chat      : main Agent 3 gateway (you talk, it plans and replies with structured JSON)." -ForegroundColor Gray
Write-Host "   - /api/codegen   : turns your instructions into files[], scripts[], next_steps[] (full product plans, not just snippets)." -ForegroundColor Gray
Write-Host "   - /api/ai/       : meta-root for AI functions." -ForegroundColor Gray
Write-Host "   - /api/ai/complete : raw text completion endpoint for low-level model calls." -ForegroundColor Gray
Write-Host "   - /api/rag       : lets NIFDU read your own projects and docs to answer with local context." -ForegroundColor Gray
Write-Host "   - /api/train, /api/rl : hooks for learning and feedback over time." -ForegroundColor Gray
Write-Host ""

Write-Host "3) TRUTH & EXECUTION" -ForegroundColor Cyan
Write-Host "   - /api/compile   : ask the compiler if the code actually builds." -ForegroundColor Gray
Write-Host "   - /api/run       : run generated programs or scripts and capture real behavior." -ForegroundColor Gray
Write-Host "   - /api/truth     : combine compile/run/tests to answer: Is this correct in reality?" -ForegroundColor Gray
Write-Host "   - /api/behavior_test : sandbox for experiments and diagnostics." -ForegroundColor Gray
Write-Host ""

Write-Host "4) AV / MEDIA BRAIN" -ForegroundColor Cyan
Write-Host "   - /api/av/control : main control plane for NIFDU AV (you send JSON describing the video/animation)." -ForegroundColor Gray
Write-Host "   - /api/av/plan    : planner stub for turning prompts into AV sequences (WIP planner)." -ForegroundColor Gray
Write-Host "   - /api/av/render  : turns AV plans into MP4 or image sequences locally." -ForegroundColor Gray
Write-Host "   - /api/av/sprite  : generates sprites/images for games, UI, and AV." -ForegroundColor Gray
Write-Host ""

Write-Host "5) OPS / INFRA / MULTI-TENANT" -ForegroundColor Cyan
Write-Host "   - /api/           : root index of what the monolith can do." -ForegroundColor Gray
Write-Host "   - /api/health     : basic health check (may be stubbed in your current build)." -ForegroundColor Gray
Write-Host "   - /api/ping       : quick ping/pong connectivity test." -ForegroundColor Gray
Write-Host "   - /api/db_health  : checks Postgres connectivity (e.g., sophyane_com_db)." -ForegroundColor Gray
Write-Host "   - /api/list       : shows what endpoints/services are available." -ForegroundColor Gray
Write-Host "   - /api/log        : central logging hook for agents and tools." -ForegroundColor Gray
Write-Host "   - /api/deploy     : one-button deploy of frontends/backends/apps." -ForegroundColor Gray
Write-Host "   - /api/proxy/config, /api/proxy/reload, /api/proxy/routes, /api/proxy/services : reverse proxy control and introspection." -ForegroundColor Gray
Write-Host ""

Write-Host "6) PRODUCT / BUSINESS LAYER" -ForegroundColor Cyan
Write-Host "   - /api/lead       : capture leads from visitors in a structured way." -ForegroundColor Gray
Write-Host "   - /api/project    : represents one project or app in the system." -ForegroundColor Gray
Write-Host "   - /api/projects/accept : mark a project as accepted/onboarded." -ForegroundColor Gray
Write-Host "   - /api/retail/blueprints : generate retail blueprints (SKUs, margins, storefront plan) for ideas like shawls, Basmati, groceries." -ForegroundColor Gray
Write-Host ""

Write-Host "7) AUTH / SECURITY" -ForegroundColor Cyan
Write-Host "   - /api/auth/generate_key : issue API keys for tenants, tools, and future external clients." -ForegroundColor Gray
Write-Host ""

Write-Host "8) VIBE / MISC" -ForegroundColor Cyan
Write-Host "   - /api/vibe       : vibe coding playground and fun diagnostics endpoint." -ForegroundColor Gray
Write-Host ""

Write-Host "9) WHY THIS BEATS REPLIT AGENT / COPILOT / CURSOR / v0 (DUMMY FOUNDER VIEW)" -ForegroundColor Cyan
Write-Host "   - Other tools mostly give you code suggestions inside *their* editor or *their* cloud." -ForegroundColor Gray
Write-Host "   - You still juggle domains, TLS, Postgres, deploy, AV, logs, and business logic yourself." -ForegroundColor Gray
Write-Host "   - NIFDU is different: one self-hosted monolith with 38+ APIs and one brain." -ForegroundColor Gray
Write-Host "   - /api/chat + /api/codegen act as a full-product engine: you describe the idea once," -ForegroundColor Gray
Write-Host "     and NIFDU plans, generates code, writes files, compiles, runs, and deploys inside the same universe." -ForegroundColor Gray
Write-Host ""

Write-Host "In short:" -ForegroundColor Yellow
Write-Host "   NIFDU is not just a code assistant. It is a self-hosted AI factory where a non-technical founder" -ForegroundColor Green
Write-Host "   can go from idea to live product by talking to one brain, instead of juggling 20 different tools." -ForegroundColor Green

