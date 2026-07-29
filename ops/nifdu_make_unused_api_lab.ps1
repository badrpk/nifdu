# ==============================================
# C:\nifdu\ops\nifdu_make_unused_api_lab.ps1
# NIFDU - MAKE UNUSED APIs LAB FRONTEND
# ----------------------------------------------
# Creates/overwrites:
#   C:\nifdu\src\apps\nifdu_api_lab_unused\src\App.tsx
#   C:\nifdu\src\apps\nifdu_api_lab_unused\src\main.tsx (if missing)
# ==============================================

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

$AppRoot = "C:\nifdu\src\apps\nifdu_api_lab_unused"
$SrcDir  = Join-Path $AppRoot "src"

Say "`n=== NIFDU - CREATE UNUSED APIs LAB FRONTEND ===`n" "Yellow"
Say "App root: $AppRoot" "Gray"

New-Item -ItemType Directory -Path $SrcDir -Force | Out-Null

# -----------------------------
# Write App.tsx
# -----------------------------
$AppTsx = @"
import React, { useState } from "react";

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

const API_SPECS = [
  {
    section: "Core / Health",
    path: "/health",
    method: "GET",
    label: "GET /health",
  },
  {
    section: "AI Extra",
    path: "/api/ai/config",
    method: "GET",
    label: "GET /api/ai/config",
  },
  {
    section: "AI Extra",
    path: "/api/ai/models",
    method: "GET",
    label: "GET /api/ai/models",
  },
  {
    section: "AI Extra",
    path: "/api/ai/embed",
    method: "POST",
    label: "POST /api/ai/embed",
  },
  {
    section: "AI Extra",
    path: "/api/ai/recall",
    method: "POST",
    label: "POST /api/ai/recall",
  },
  {
    section: "AV Extra",
    path: "/api/av/plan",
    method: "POST",
    label: "POST /api/av/plan",
  },
  {
    section: "AV Extra",
    path: "/api/av/sprite",
    method: "POST",
    label: "POST /api/av/sprite",
  },
  {
    section: "AV Extra",
    path: "/api/av/render",
    method: "POST",
    label: "POST /api/av/render",
  },
  {
    section: "AV Extra",
    path: "/api/av/control",
    method: "POST",
    label: "POST /api/av/control",
  },
  {
    section: "Behavior Test",
    path: "/api/behavior_test",
    method: "GET",
    label: "GET /api/behavior_test",
  },
  {
    section: "Retail / Proxy / Prices",
    path: "/api/retail",
    method: "GET",
    label: "GET /api/retail",
  },
  {
    section: "Retail / Proxy / Prices",
    path: "/api/proxy/config",
    method: "GET",
    label: "GET /api/proxy/config",
  },
  {
    section: "Retail / Proxy / Prices",
    path: "/api/proxy/reload",
    method: "POST",
    label: "POST /api/proxy/reload",
  },
  {
    section: "Retail / Proxy / Prices",
    path: "/api/ws/prices",
    method: "GET",
    label: "GET /api/ws/prices",
  },
];

function prettyJson(value: any): string {
  if (value === undefined) return "";
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return JSON.stringify(parsed, null, 2);
    } catch {
      return value;
    }
  }
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}

export default function App() {
  const [activeSection, setActiveSection] = useState<string>("Core / Health");
  const [results, setResults] = useState<Record<
    string,
    {
      loading?: boolean;
      status?: number;
      ok?: boolean;
      error?: string;
      body?: any;
    }
  >>({});

  const [aiText, setAiText] = useState<string>("Hello from NIFDU AI.");
  const [recallText, setRecallText] = useState<string>("What did I store?");
  const [avPrompt, setAvPrompt] = useState<string>("cat walking in the rain");
  const [reloadReason, setReloadReason] = useState<string>("manual");
  const [log, setLog] = useState<string[]>([]);

  const sections = Array.from(
    new Set(API_SPECS.map((s) => s.section))
  );

  function appendLog(msg: string) {
    setLog((prev) => [`[\${new Date().toLocaleTimeString()}] \${msg}`, ...prev].slice(0, 200));
  }

  async function callApi(path: string, method: string) {
    setResults((prev) => ({
      ...prev,
      [path]: { ...prev[path], loading: true, error: undefined },
    }));

    let body: any = undefined;

    if (path === "/api/ai/embed") {
      body = { text: aiText || "hello from nifdu /api/ai/embed" };
    } else if (path === "/api/ai/recall") {
      body = { query: recallText || "recall my previous text" };
    } else if (path === "/api/av/plan") {
      body = { prompt: avPrompt || "simple av plan demo" };
    } else if (path === "/api/av/sprite") {
      body = { name: "demo_sprite", frames: 10 };
    } else if (path === "/api/av/render") {
      body = { plan_id: "demo-plan-id" };
    } else if (path === "/api/av/control") {
      body = { action: "play", speed: 1.0 };
    } else if (path === "/api/proxy/reload") {
      body = { reason: reloadReason || "manual" };
    }

    let options: RequestInit = { method };
    if (method === "POST") {
      options.headers = { "Content-Type": "application/json" };
      options.body = JSON.stringify(body ?? {});
    }

    appendLog(\`Calling \${method} \${path}\`);

    try {
      const res = await fetch(path, options);
      const status = res.status;
      const text = await res.text();
      let parsed: any = text;
      try {
        parsed = JSON.parse(text);
      } catch {
        // keep text
      }

      setResults((prev) => ({
        ...prev,
        [path]: {
          loading: false,
          status,
          ok: res.ok,
          body: parsed,
        },
      }));

      appendLog(\`OK \${method} \${path} -> \${status}\`);
    } catch (err: any) {
      const message = err?.message ?? String(err);
      setResults((prev) => ({
        ...prev,
        [path]: {
          loading: false,
          error: message,
        },
      }));
      appendLog(\`ERROR \${method} \${path} -> \${message}\`);
    }
  }

  function renderSectionControls(section: string) {
    if (section === "AI Extra") {
      return (
        <div className="mb-4 grid gap-4 md:grid-cols-2">
          <div>
            <label className="block text-xs text-slate-400 mb-1">
              Embed text (/api/ai/embed)
            </label>
            <textarea
              className="w-full rounded-xl bg-slate-900 border border-slate-700 px-3 py-2 text-sm text-slate-100"
              rows={3}
              value={aiText}
              onChange={(e) => setAiText(e.target.value)}
            />
          </div>
          <div>
            <label className="block text-xs text-slate-400 mb-1">
              Recall query (/api/ai/recall)
            </label>
            <textarea
              className="w-full rounded-xl bg-slate-900 border border-slate-700 px-3 py-2 text-sm text-slate-100"
              rows={3}
              value={recallText}
              onChange={(e) => setRecallText(e.target.value)}
            />
          </div>
        </div>
      );
    }

    if (section === "AV Extra") {
      return (
        <div className="mb-4">
          <label className="block text-xs text-slate-400 mb-1">
            AV prompt (used by /api/av/plan)
          </label>
          <textarea
            className="w-full rounded-xl bg-slate-900 border border-slate-700 px-3 py-2 text-sm text-slate-100"
            rows={3}
            value={avPrompt}
            onChange={(e) => setAvPrompt(e.target.value)}
          />
        </div>
      );
    }

    if (section === "Retail / Proxy / Prices") {
      return (
        <div className="mb-4">
          <label className="block text-xs text-slate-400 mb-1">
            Proxy reload reason (/api/proxy/reload)
          </label>
          <input
            className="w-full rounded-xl bg-slate-900 border border-slate-700 px-3 py-2 text-sm text-slate-100"
            value={reloadReason}
            onChange={(e) => setReloadReason(e.target.value)}
          />
        </div>
      );
    }

    return null;
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <div className="max-w-6xl mx-auto px-4 py-6">
        <header className="mb-6">
          <h1 className="text-2xl md:text-3xl font-bold text-emerald-400">
            NIFDU API Lab - Unused APIs
          </h1>
          <p className="text-slate-400 text-sm md:text-base mt-1">
            React + Tailwind dashboard that exercises all previously UNUSED
            NIFDU endpoints using relative URLs (fetch("/api/...")).
          </p>
          <p className="text-xs text-slate-500 mt-1">
            This page is designed so the NIFDU API scanner will see all of:
            /health, /api/ai/config, /api/ai/models, /api/ai/embed,
            /api/ai/recall, /api/av/plan, /api/av/sprite, /api/av/render,
            /api/av/control, /api/behavior_test, /api/proxy/config,
            /api/proxy/reload, /api/retail, /api/ws/prices.
          </p>
        </header>

        <div className="flex flex-col md:flex-row gap-4">
          <div className="md:w-2/3 space-y-4">
            {/* Section tabs */}
            <div className="flex flex-wrap gap-2 mb-2">
              {sections.map((sec) => (
                <button
                  key={sec}
                  onClick={() => setActiveSection(sec)}
                  className={
                    "px-3 py-1.5 rounded-full text-xs font-medium border " +
                    (sec === activeSection
                      ? "bg-emerald-500/20 border-emerald-500 text-emerald-300"
                      : "bg-slate-900 border-slate-700 text-slate-300 hover:bg-slate-800")
                  }
                >
                  {sec}
                </button>
              ))}
            </div>

            {/* Section-specific input controls */}
            {renderSectionControls(activeSection)}

            {/* Cards for APIs in this section */}
            <div className="grid gap-3 md:grid-cols-2">
              {API_SPECS.filter((s) => s.section === activeSection).map(
                (spec) => {
                  const r = results[spec.path] || {};
                  return (
                    <div
                      key={spec.path}
                      className="rounded-2xl bg-slate-900 border border-slate-700 p-3 flex flex-col gap-2"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="text-xs font-mono text-slate-300">
                          <span
                            className={
                              "px-2 py-0.5 rounded-full text-[10px] font-semibold mr-1 " +
                              (spec.method === "GET"
                                ? "bg-blue-500/20 text-blue-300"
                                : "bg-amber-500/20 text-amber-300")
                            }
                          >
                            {spec.method}
                          </span>
                          {spec.path}
                        </div>
                        <button
                          onClick={() =>
                            callApi(spec.path, spec.method)
                          }
                          className="text-xs px-2 py-1 rounded-full bg-emerald-500/20 text-emerald-200 border border-emerald-500 hover:bg-emerald-500/30"
                          disabled={r.loading}
                        >
                          {r.loading ? "Calling..." : "Call"}
                        </button>
                      </div>

                      {r.status !== undefined && (
                        <div className="text-[11px] text-slate-400">
                          Status:{" "}
                          <span
                            className={
                              r.ok
                                ? "text-emerald-300 font-semibold"
                                : "text-red-300 font-semibold"
                            }
                          >
                            {r.status}
                          </span>
                        </div>
                      )}

                      {r.error && (
                        <div className="text-[11px] text-red-300 bg-red-950/40 border border-red-700/60 rounded-xl px-2 py-1">
                          Error: {r.error}
                        </div>
                      )}

                      {r.body !== undefined && !r.error && (
                        <pre className="text-[11px] leading-snug bg-slate-950/70 border border-slate-800 rounded-xl px-2 py-2 overflow-auto max-h-40">
                          {prettyJson(r.body)}
                        </pre>
                      )}

                      {!r.body && !r.error && !r.loading && (
                        <div className="text-[11px] text-slate-500">
                          Click <span className="font-semibold">Call</span> to
                          hit this endpoint.
                        </div>
                      )}
                    </div>
                  );
                }
              )}
            </div>
          </div>

          {/* Side log panel */}
          <div className="md:w-1/3">
            <div className="h-full rounded-2xl bg-slate-900 border border-slate-700 p-3 flex flex-col">
              <div className="flex items-center justify-between mb-2">
                <h2 className="text-xs font-semibold text-slate-200">
                  Call log
                </h2>
                <button
                  className="text-[10px] text-slate-400 hover:text-slate-200"
                  onClick={() => setLog([])}
                >
                  Clear
                </button>
              </div>
              <div className="flex-1 overflow-auto text-[11px] font-mono text-slate-300 space-y-1">
                {log.length === 0 && (
                  <div className="text-slate-500">
                    No calls yet. Use the cards on the left to hit each API.
                  </div>
                )}
                {log.map((line, idx) => (
                  <div key={idx}>{line}</div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
"@

$AppPath = Join-Path $SrcDir "App.tsx"
$AppTsx | Set-Content -Encoding UTF8 $AppPath
Say "Wrote App.tsx -> $AppPath" "Green"

# -----------------------------
# Write main.tsx if missing
# -----------------------------
$MainPath = Join-Path $SrcDir "main.tsx"
if (-not (Test-Path $MainPath)) {
    $MainTsx = @"
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

import "./index.css";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
"@
    $MainTsx | Set-Content -Encoding UTF8 $MainPath
    Say "Created main.tsx -> $MainPath" "Green"
} else {
    Say "main.tsx already exists, not touching it." "Gray"
}

Say "`n=== NIFDU - UNUSED APIs LAB FRONTEND READY ===`n" "Cyan"
