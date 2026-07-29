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
# C:\nifdu\ops\sophyane_dual_core_full_wire.ps1
# SOPHYANE — DUAL-CORE VIBE CODING WIRING
# ----------------------------------------------
# - Overwrites app/page.tsx with working Dual-Core UI
# - Creates app/api/sophyane/chat/route.ts (proxy to NIFDU /api/chat)
# - Creates NIFDU Raw Lab static HTML at:
#     C:\webroot\nifdu.com\www\apps\vibe_static_lab\index.html
# ==============================================
param()

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

Say "`n=== SOPHYANE DUAL-CORE FULL WIRE ===`n" "Yellow"

# Paths
$appRoot   = "C:\nifdu\src\apps\sophyane_live"
$appDir    = Join-Path $appRoot "app"
$pagePath  = Join-Path $appDir "page.tsx"
$apiDir    = Join-Path $appDir "api\sophyane\chat"
$routePath = Join-Path $apiDir "route.ts"
$labRoot   = "C:\webroot\nifdu.com\www\apps\vibe_static_lab"
$labIndex  = Join-Path $labRoot "index.html"

# Ensure folders exist
foreach ($d in @($appDir, $apiDir, $labRoot)) {
    if (!(Test-Path $d)) {
        Say "Creating folder: $d" "Yellow"
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

# ----------------------------------------------
# 1) Write Dual-Core page.tsx with working chat
# ----------------------------------------------
$tsx = @'
"use client";

import React, { useState } from "react";

type Mode = "sophyane" | "nifdu";

type ChatMessage = {
  from: "user" | "ai";
  text: string;
};

export default function Home() {
  const [mode, setMode] = useState<Mode>("sophyane");

  return (
    <div className="min-h-screen bg-slate-950 text-slate-50 flex flex-col">
      <Header mode={mode} setMode={setMode} />
      <main className="flex-1 flex overflow-hidden border-t border-slate-800">
        {mode === "sophyane" ? <SophyaneWorkspace /> : <NifduRawWorkspace />}
      </main>
    </div>
  );
}

function Header(props: { mode: Mode; setMode: (m: Mode) => void }) {
  const { mode, setMode } = props;
  return (
    <header className="h-12 px-4 flex items-center justify-between bg-slate-950 border-b border-slate-800">
      <div className="flex items-center gap-2 text-xs font-semibold tracking-[0.18em] uppercase">
        <span className="px-2 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/40">
          NIFDU • Dual-Core
        </span>
        <span className="text-slate-400">Sophyane Vibe Coding</span>
      </div>
      <div className="flex items-center gap-2 text-xs">
        <ModeToggle
          label="Sophyane IDE"
          active={mode === "sophyane"}
          onClick={() => setMode("sophyane")}
        />
        <ModeToggle
          label="NIFDU Raw Lab"
          active={mode === "nifdu"}
          onClick={() => setMode("nifdu")}
        />
      </div>
    </header>
  );
}

function ModeToggle(props: { label: string; active: boolean; onClick: () => void }) {
  const { label, active, onClick } = props;
  return (
    <button
      onClick={onClick}
      className={
        "px-3 py-1 rounded-full border text-[11px] transition-colors " +
        (active
          ? "bg-emerald-500 text-slate-950 border-emerald-400"
          : "bg-slate-900 text-slate-300 border-slate-700 hover:border-emerald-400/60")
      }
    >
      {label}
    </button>
  );
}

/**
 * Sophyane Mode — dynamic IDE cockpit + wired Agent 3 chat
 */
function SophyaneWorkspace() {
  const [messages, setMessages] = useState<ChatMessage[]>([
    { from: "ai", text: "Agent 3 (Sophyane mode) ready. Describe the product you want to build." },
  ]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);

  async function send() {
    const trimmed = input.trim();
    if (!trimmed || sending) return;

    const userMsg: ChatMessage = { from: "user", text: trimmed };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setSending(true);

    try {
      const res = await fetch("/api/sophyane/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          project: "sophyane_live",
          mode: "vibe_coding",
          brain: "auto",
          prompt: trimmed,
        }),
      });

      const json = await res.json();
      const replyText =
        json.reply ||
        json.message ||
        json.text ||
        JSON.stringify(json, null, 2);

      const aiMsg: ChatMessage = { from: "ai", text: replyText };
      setMessages((prev) => [...prev, aiMsg]);
    } catch (err: any) {
      const aiMsg: ChatMessage = {
        from: "ai",
        text: "Error calling /api/sophyane/chat → " + String(err),
      };
      setMessages((prev) => [...prev, aiMsg]);
    } finally {
      setSending(false);
    }
  }

  function handleKey(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      void send();
    }
  }

  return (
    <div className="flex flex-1 overflow-hidden">
      {/* Left: project / files */}
      <div className="w-60 border-r border-slate-800 bg-slate-950/80">
        <PanelTitle title="Projects" subtitle="Sophyane IDE" />
        <div className="p-2 text-xs text-slate-400 space-y-1">
          <div className="rounded-md border border-slate-800 px-2 py-1 bg-slate-900/60">
            <div className="text-slate-100">sophyane_live</div>
            <div className="text-[10px] text-emerald-400">
              Next.js · App Router · port 3001
            </div>
          </div>
          <div className="rounded-md border border-slate-800 px-2 py-1 bg-slate-900/30">
            <div className="text-slate-100">nifdu_monolith</div>
            <div className="text-[10px] text-slate-500">
              C++ · HTTP80-core · /api/*
            </div>
          </div>
        </div>
      </div>

      {/* Center: editor / preview */}
      <div className="flex-1 flex flex-col border-r border-slate-800 bg-slate-950">
        <PanelTitle title="Editor & Preview" subtitle="Sophyane dynamic mode" />
        <div className="flex-1 grid grid-cols-2 gap-1 p-2">
          <div className="border border-slate-800 rounded-md bg-slate-900/60 p-2 text-xs">
            <div className="mb-1 text-[10px] text-slate-400">app/page.tsx</div>
            <pre className="whitespace-pre-wrap text-[11px] text-slate-200">
{`// This is the Sophyane IDE cockpit.
// Here you can show:
//  - File explorer
//  - Editor
//  - Live preview
//  - Build logs
//  - etc.
//
// The magic is: you never leave this page.
// You only swap panels inside this layout.`}
            </pre>
          </div>
          <div className="border border-slate-800 rounded-md bg-slate-900/40 p-2 text-xs">
            <div className="mb-1 text-[10px] text-slate-400">Live Preview</div>
            <div className="h-full flex items-center justify-center text-slate-400 text-[11px]">
              Sophyane dynamic preview goes here (React, hot state, animated UI).
            </div>
          </div>
        </div>
      </div>

      {/* Right: Agent 3 chat */}
      <div className="w-[320px] bg-slate-950/90">
        <PanelTitle title="Agent 3" subtitle="Sophyane Frontend" />
        <div className="p-2 text-xs h-[calc(100%-2.5rem)] flex flex-col">
          <div className="flex-1 border border-slate-800 rounded-md bg-slate-900/60 p-2 overflow-auto space-y-1">
            {messages.map((m, i) => (
              <div
                key={i}
                className={
                  "px-2 py-1 rounded-md border text-[11px] " +
                  (m.from === "user"
                    ? "border-emerald-500/60 bg-emerald-500/10 text-emerald-200 self-end"
                    : "border-slate-700 bg-slate-900 text-slate-100 self-start")
                }
              >
                {m.text}
              </div>
            ))}
          </div>
          <div className="mt-2 flex gap-2">
            <textarea
              className="flex-1 border border-slate-800 rounded-md bg-slate-900/80 text-[11px] p-2 outline-none"
              rows={3}
              placeholder="Type a prompt to Agent 3 (Sophyane Mode)…"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKey}
            />
            <button
              onClick={send}
              disabled={sending}
              className="px-3 py-2 rounded-md bg-emerald-500 text-slate-950 text-[11px] font-semibold border border-emerald-400 disabled:opacity-50"
            >
              {sending ? "..." : "Send"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * NIFDU Mode — iframe bridge into raw HTTP80 vibe lab
 */
function NifduRawWorkspace() {
  return (
    <div className="flex-1 flex flex-col bg-black">
      <div className="h-10 px-4 flex items-center justify-between border-b border-slate-800 bg-black/80 text-xs">
        <div className="text-slate-300 flex items-center gap-2">
          <span className="inline-block w-2 h-2 rounded-full bg-emerald-400" />
          <span>NIFDU Raw Lab • /apps/vibe_static_lab/</span>
        </div>
        <div className="text-[10px] text-slate-500">
          Served directly by nifdu.exe on HTTP-core
        </div>
      </div>
      <iframe
        src="/apps/vibe_static_lab/"
        className="flex-1 w-full border-none bg-black"
        title="NIFDU Raw Vibe Lab"
      />
    </div>
  );
}

function PanelTitle(props: { title: string; subtitle?: string }) {
  return (
    <div className="h-10 px-3 flex items-center justify-between border-b border-slate-800 bg-slate-950/90 text-[11px]">
    <span className="text-slate-200 tracking-[0.16em] uppercase">
        {props.title}
      </span>
      {props.subtitle && (
        <span className="text-slate-500">{props.subtitle}</span>
      )}
    </div>
  );
}
'@

Say "Writing Dual-Core page.tsx:" "Yellow"
Say "  $pagePath" "Cyan"
Set-Content -Path $pagePath -Value $tsx -Encoding UTF8

# ----------------------------------------------
# 2) Write API proxy: /api/sophyane/chat -> NIFDU /api/chat
# ----------------------------------------------
$routeTs = @'
import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const payload = {
    project: body.project ?? "sophyane_live",
    mode: body.mode ?? "vibe_coding",
    brain: body.brain ?? "auto",
    prompt: body.prompt ?? body.message ?? "",
  };

  try {
    // IMPORTANT:
    //  - If NIFDU is on 8000: use http://127.0.0.1:8000/api/chat
    //  - If NIFDU still owns 80: use http://127.0.0.1/api/chat
    const res = await fetch("http://127.0.0.1:8000/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const json = await res.json();
    return NextResponse.json(json, { status: 200 });
  } catch (err: any) {
    return NextResponse.json(
      {
        error: "proxy_failed",
        detail: String(err),
      },
      { status: 500 },
    );
  }
}
'@

Say "Writing API proxy route.ts:" "Yellow"
Say "  $routePath" "Cyan"
Set-Content -Path $routePath -Value $routeTs -Encoding UTF8

# ----------------------------------------------
# 3) Write NIFDU Raw Lab static HTML
# ----------------------------------------------
$html = @'
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="utf-8" />
  <title>NIFDU Vibe Lab — vibe_static_lab</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root {
      color-scheme: dark;
    }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #020617;
      color: #e5e7eb;
    }
    .shell {
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    header {
      height: 48px;
      padding: 0 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid #1f2937;
      background: rgba(2,6,23,0.98);
    }
    header .title {
      font-size: 11px;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      color: #9ca3af;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    header .pill {
      padding: 2px 8px;
      border-radius: 999px;
      border: 1px solid rgba(16,185,129,0.5);
      background: rgba(16,185,129,0.08);
      color: #6ee7b7;
      font-size: 10px;
    }
    main {
      flex: 1;
      display: grid;
      grid-template-columns: minmax(0, 1.1fr) minmax(0, 0.9fr);
      gap: 1px;
      background: #020617;
    }
    .panel {
      padding: 12px;
      background: radial-gradient(circle at top left, #020617 0, #020617 40%, #020617 100%);
      border-top: 1px solid #111827;
    }
    .panel-inner {
      border-radius: 10px;
      border: 1px solid #1f2937;
      background: rgba(15,23,42,0.85);
      padding: 8px;
      font-size: 11px;
    }
    .panel-title {
      font-size: 10px;
      color: #9ca3af;
      margin-bottom: 6px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    textarea {
      width: 100%;
      resize: vertical;
      min-height: 120px;
      max-height: 260px;
      border-radius: 8px;
      border: 1px solid #1f2937;
      background: #020617;
      color: #e5e7eb;
      font-size: 11px;
      padding: 8px;
      box-sizing: border-box;
    }
    textarea:focus {
      outline: none;
      border-color: #22c55e;
      box-shadow: 0 0 0 1px rgba(34,197,94,0.4);
    }
    button {
      border-radius: 8px;
      border: 1px solid #22c55e;
      background: #22c55e;
      color: #020617;
      font-size: 11px;
      padding: 6px 12px;
      font-weight: 600;
      cursor: pointer;
    }
    button:disabled {
      opacity: 0.6;
      cursor: default;
    }
    .muted {
      font-size: 10px;
      color: #6b7280;
    }
    pre {
      white-space: pre-wrap;
      word-break: break-word;
      margin: 0;
      font-size: 11px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      color: #e5e7eb;
    }
    .log {
      max-height: calc(100vh - 140px);
      overflow: auto;
      border-radius: 8px;
      border: 1px solid #111827;
      background: #020617;
      padding: 8px;
    }
    .log-entry {
      padding: 4px 6px;
      border-radius: 6px;
      margin-bottom: 4px;
      border: 1px solid #1f2937;
      background: rgba(15,23,42,0.9);
    }
    .log-entry.system {
      border-color: rgba(148,163,184,0.6);
      color: #9ca3af;
    }
    .log-entry.ok {
      border-color: rgba(34,197,94,0.6);
      color: #bbf7d0;
    }
    .log-entry.err {
      border-color: rgba(248,113,113,0.6);
      color: #fecaca;
    }
    code {
      font-family: inherit;
      background: rgba(15,23,42,0.8);
      padding: 1px 4px;
      border-radius: 4px;
    }
  </style>
</head>
<body>
  <div class="shell">
    <header>
      <div class="title">
        <span class="pill">NIFDU · RAW VIBE LAB</span>
        <span>apps/vibe_static_lab · HTTP-core</span>
      </div>
      <div class="muted">
        Direct static · No framework · Talking to <code>/api/chat</code>
      </div>
    </header>
    <main>
      <section class="panel">
        <div class="panel-inner">
          <div class="panel-title">
            <span>Prompt → /api/chat (Agent 3)</span>
            <span class="muted">This is the bare metal test bench.</span>
          </div>
          <textarea id="prompt" placeholder="Describe what you want Agent 3 + NIFDU to build (e.g. 'Next.js + C++ backend for todo app with Postgres and mobile app stubs')."></textarea>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-top:8px;gap:8px;">
            <button id="runBtn">Send to Agent 3</button>
            <div class="muted">
              POST <code>/api/chat</code> · payload: { project, mode, brain, prompt }
            </div>
          </div>
        </div>
      </section>
      <section class="panel">
        <div class="panel-inner">
          <div class="panel-title">
            <span>Response / Logs</span>
            <span class="muted">If this works, the whole NIFDU brain is alive.</span>
          </div>
          <div id="log" class="log"></div>
        </div>
      </section>
    </main>
  </div>

  <script>
    const runBtn = document.getElementById("runBtn");
    const promptEl = document.getElementById("prompt");
    const logEl = document.getElementById("log");

    function addLog(kind, text) {
      const div = document.createElement("div");
      div.className = "log-entry " + kind;
      div.textContent = text;
      logEl.appendChild(div);
      logEl.scrollTop = logEl.scrollHeight;
    }

    async function callAgent() {
      const text = promptEl.value.trim();
      if (!text) {
        addLog("system", "Type a prompt first.");
        return;
      }
      runBtn.disabled = true;
      addLog("system", "Calling /api/chat via Caddy + NIFDU...");

      try {
        const res = await fetch("/api/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            project: "vibe_static_lab",
            mode: "vibe_coding",
            brain: "auto",
            prompt: text
          })
        });

        const json = await res.json();
        addLog("ok", JSON.stringify(json, null, 2));
      } catch (err) {
        addLog("err", "Request failed: " + err);
      } finally {
        runBtn.disabled = false;
      }
    }

    runBtn.addEventListener("click", callAgent);
  </script>
</body>
</html>
'@

Say "Writing NIFDU Raw Lab HTML:" "Yellow"
Say "  $labIndex" "Cyan"
Set-Content -Path $labIndex -Value $html -Encoding UTF8

Say "`n=== DONE: Sophyane Dual-Core wired ===" "Green"
Say "Now:" "Cyan"
Say "  1) Ensure NIFDU monolith is running (port 8000 for /api/*)." "Cyan"
Say "  2) Ensure Caddy is proxying /apps/* and /api/* correctly for sophyane.com." "Cyan"
Say "  3) In C:\nifdu\src\apps\sophyane_live run: node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev  OR  pnpm start --port 3001." "Cyan"
Say "  4) Open https://sophyane.com (or http://localhost:3001) to use Dual-Core UI." "Cyan"
