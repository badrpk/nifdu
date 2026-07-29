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
# C:\nifdu\ops\nifdu_sophyane_patch_chat_and_studio.ps1
# NIFDU / SOPHYANE — PATCH CHAT API + STUDIO UI
# ==============================================

param(
    [string]$AppRoot      = "C:/nifdu/src/apps/sophyane_live",
    [string]$NifduBaseUrl = "http://127.0.0.1:8000",
    [string]$ProjectId    = "sophyane_live"
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

Clear-Host
Say "=== NIFDU / SOPHYANE — PATCH CHAT API + STUDIO UI ===`n" "Yellow"
Say "App root: $AppRoot" "Gray"

if (-not (Test-Path $AppRoot)) {
    Say "ERROR: App root does not exist: $AppRoot" "Red"
    Say "Make sure the Sophyane app has been generated first." "Red"
    exit 1
}

# -----------------------------
# Helper: write UTF-8 (OK with BOM for TS/TSX)
# -----------------------------
function Write-FileUtf8 {
    param(
        [string]$Path,
        [string]$Content
    )

    if (-not $Path) { return }

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $Content | Set-Content -Path $Path -Encoding UTF8
}

# -----------------------------
# 1) .env.local
# -----------------------------
Say "`nStep 1 - Writing .env.local ..." "Cyan"

$envPath = Join-Path $AppRoot ".env.local"
$envContent = @"
NIFDU_BASE_URL=$NifduBaseUrl
NIFDU_PROJECT_ID=$ProjectId
"@

Write-FileUtf8 -Path $envPath -Content $envContent
Say "Wrote $envPath" "Green"

# -----------------------------
# 2) app/api/sophyane/chat/route.ts
# -----------------------------
Say "`nStep 2 - Writing app/api/sophyane/chat/route.ts ..." "Cyan"

$routePath = Join-Path $AppRoot "app/api/sophyane/chat/route.ts"
$routeContent = @'
import { NextRequest, NextResponse } from "next/server";

const NIFDU_BASE_URL = process.env.NIFDU_BASE_URL ?? "http://127.0.0.1:8000";
const NIFDU_PROJECT_ID = process.env.NIFDU_PROJECT_ID ?? "sophyane_live";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const message: string = body?.message ?? "";

    if (!message.trim()) {
      return NextResponse.json(
        { error: "missing_message", detail: "message is required" },
        { status: 400 }
      );
    }

    const nifduPayload = {
      project: NIFDU_PROJECT_ID,
      brain: "auto",
      mode: "vibe_coding",
      prompt: message,
    };

    const res = await fetch(`${NIFDU_BASE_URL}/api/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify(nifduPayload),
    });

    if (!res.ok) {
      const text = await res.text();
      return NextResponse.json(
        {
          error: "nifdu_chat_failed",
          status: res.status,
          detail: text,
        },
        { status: 502 }
      );
    }

    const data = await res.json();

    return NextResponse.json(
      {
        ok: true,
        engine: data.engine ?? "unknown",
        raw: data,
      },
      { status: 200 }
    );
  } catch (err: any) {
    console.error("Sophyane /api/sophyane/chat error:", err);
    return NextResponse.json(
      {
        error: "internal",
        detail: err?.message ?? String(err),
      },
      { status: 500 }
    );
  }
}
'@

Write-FileUtf8 -Path $routePath -Content $routeContent
Say "Wrote $routePath" "Green"

# -----------------------------
# 3) app/studio/page.tsx
# -----------------------------
Say "`nStep 3 - Writing app/studio/page.tsx ..." "Cyan"

$studioPath = Join-Path $AppRoot "app/studio/page.tsx"
$studioContent = @'
"use client";

import React, { useState } from "react";

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
};

export default function StudioPage() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [lastRaw, setLastRaw] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSend = async () => {
    const trimmed = input.trim();
    if (!trimmed || loading) return;

    const userMsg: ChatMessage = { role: "user", content: trimmed };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setLoading(true);
    setError(null);

    try {
      const res = await fetch("/api/sophyane/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message: trimmed }),
      });

      const data = await res.json();
      setLastRaw(data);

      if (!res.ok || !data.ok) {
        setError(
          data?.detail ||
            data?.error ||
            `Request failed with status ${res.status}`
        );
        const errMsg: ChatMessage = {
          role: "assistant",
          content: "Something went wrong talking to NIFDU.",
        };
        setMessages((prev) => [...prev, errMsg]);
        return;
      }

      const pretty =
        typeof data.raw === "string"
          ? data.raw
          : JSON.stringify(data.raw, null, 2);

      const assistantMsg: ChatMessage = {
        role: "assistant",
        content: `Engine: ${data.engine}\n\n${pretty}`,
      };

      setMessages((prev) => [...prev, assistantMsg]);
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Unknown error");
      const errMsg: ChatMessage = {
        role: "assistant",
        content: "Unexpected error talking to NIFDU.",
      };
      setMessages((prev) => [...prev, errMsg]);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown: React.KeyboardEventHandler<HTMLTextAreaElement> = (
    e
  ) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      void handleSend();
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      <header className="border-b border-slate-800 px-6 py-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-emerald-400">
            Sophyane Vibe Coding Studio
          </h1>
          <p className="text-xs text-slate-400">
            Powered by NIFDU Agent 3 — chatting directly with your local
            monolith.
          </p>
        </div>
        <div className="text-xs text-slate-500">
          NIFDU base:
          <code className="bg-slate-900 px-2 py-1 rounded ml-1">
            local NIFDU (http://127.0.0.1:8000)
          </code>
        </div>
      </header>

      <main className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-4 p-4">
        <section className="col-span-1 flex flex-col bg-slate-900/60 border border-slate-800 rounded-xl">
          <div className="p-3 border-b border-slate-800">
            <h2 className="text-sm font-semibold text-emerald-300">
              Talk to Sophyane
            </h2>
            <p className="text-xs text-slate-400">
              Describe what you want to build. NIFDU will respond with plans
              and code.
            </p>
          </div>

          <div className="flex-1 overflow-y-auto p-3 space-y-2 text-xs">
            {messages.length === 0 && (
              <p className="text-slate-500">
                Start by saying something like:{" "}
                <span className="text-emerald-400">
                  "Build a landing page that explains NIFDU's 38 APIs for a
                  dummy founder."
                </span>
              </p>
            )}

            {messages.map((m, idx) => (
              <div
                key={idx}
                className={`p-2 rounded-lg ${
                  m.role === "user"
                    ? "bg-slate-800 text-slate-100"
                    : "bg-slate-900 text-emerald-200 border border-emerald-900/40"
                }`}
              >
                <div className="text-[10px] uppercase tracking-wide mb-1 opacity-60">
                  {m.role === "user" ? "You" : "NIFDU / Agent 3"}
                </div>
                <pre className="whitespace-pre-wrap text-[11px]">
                  {m.content}
                </pre>
              </div>
            ))}
          </div>

          <div className="border-t border-slate-800 p-3 space-y-2">
            <textarea
              className="w-full rounded-lg bg-slate-950 border border-slate-700 px-3 py-2 text-xs outline-none focus:ring-1 focus:ring-emerald-400 focus:border-emerald-400 resize-none"
              rows={3}
              placeholder="Describe the app or change you want..."
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
            />
            <button
              onClick={handleSend}
              disabled={loading || !input.trim()}
              className="w-full inline-flex items-center justify-center rounded-lg bg-emerald-500 text-slate-950 text-xs font-semibold py-2 hover:bg-emerald-400 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? "Thinking..." : "Send to NIFDU"}
            </button>
            {error && (
              <p className="text-[11px] text-red-400">
                Error talking to NIFDU: {error}
              </p>
            )}
          </div>
        </section>

        <section className="col-span-1 bg-slate-900/40 border border-slate-800 rounded-xl p-3 flex flex-col text-xs">
          <h2 className="text-sm font-semibold text-slate-200 mb-2">
            Project Files (placeholder)
          </h2>
          <p className="text-slate-400 mb-2">
            In future iterations, this panel will show real files from{" "}
            <code className="bg-slate-950 px-1 py-0.5 rounded">
              C:/nifdu/src/apps/sophyane_live
            </code>{" "}
            and let you preview them.
          </p>
          <ul className="space-y-1">
            <li className="px-2 py-1 rounded bg-slate-950 border border-slate-800/60">
              app/page.tsx
            </li>
            <li className="px-2 py-1 rounded bg-slate-950 border border-slate-800/60">
              app/studio/page.tsx
            </li>
            <li className="px-2 py-1 rounded bg-slate-950 border border-slate-800/60">
              app/api/sophyane/chat/route.ts
            </li>
            <li className="px-2 py-1 rounded bg-slate-950 border border-slate-800/60">
              next.config.js
            </li>
          </ul>
        </section>

        <section className="col-span-1 bg-slate-900/40 border border-slate-800 rounded-xl p-3 flex flex-col text-xs">
          <h2 className="text-sm font-semibold text-slate-200 mb-2">
            Preview and Status
          </h2>
          <p className="text-slate-400 mb-2">
            This panel summarizes the last response from NIFDU and gives you
            basic instructions.
          </p>

          <div className="mb-3">
            <h3 className="text-[11px] font-semibold text-emerald-300 mb-1">
              Dev Instructions
            </h3>
            <ol className="list-decimal list-inside space-y-1 text-slate-400">
              <li>Keep this dev server running: <code>node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev</code></li>
              <li>
                NIFDU will write and update files in{" "}
                <code className="bg-slate-950 px-1 py-0.5 rounded">
                  C:/nifdu/src/apps/sophyane_live
                </code>
              </li>
              <li>
                Future iterations will auto-run <code>pnpm build</code> from
                the NIFDU side as a truth test.
              </li>
            </ol>
          </div>

          <div className="flex-1 overflow-auto">
            <h3 className="text-[11px] font-semibold text-emerald-300 mb-1">
              Last raw response (debug)
            </h3>
            {lastRaw ? (
              <pre className="bg-slate-950 border border-slate-800 rounded-lg p-2 text-[10px] whitespace-pre-wrap">
                {JSON.stringify(lastRaw, null, 2)}
              </pre>
            ) : (
              <p className="text-slate-500">
                Send something in the chat to see NIFDU's raw JSON here.
              </p>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
'@

Write-FileUtf8 -Path $studioPath -Content $studioContent
Say "Wrote $studioPath" "Green"

Say "`n=== DONE ===" "Yellow"
Say "Patched:" "Gray"
Say "  - $envPath" "Gray"
Say "  - $routePath" "Gray"
Say "  - $studioPath" "Gray"
Say "`nNext steps:" "DarkGray"
Say "  1) cd $AppRoot" "DarkGray"
Say "  2) node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev (if not already running)" "DarkGray"
Say "  3) Open http://localhost:3000/studio" "DarkGray"
Say "  4) Chat with Sophyane and watch raw NIFDU JSON on the right." "DarkGray"
