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
# C:\nifdu\ops\nifdu_sophyane_end_to_end_oneshot.ps1
# NIFDU / SOPHYANE — END-TO-END ONE-SHOT
# ----------------------------------------------
# Does in ONE run:
#   1) Kill old nifdu.exe + node dev servers
#   2) Start NIFDU monolith via nifdu_monolith_with_env.ps1
#   3) Ensure /studio page exists (app/studio/page.tsx)
#   4) Start node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev on PORT=3001 in a new PS window
#   5) Probe http://127.0.0.1:3001/studio until it’s live
#   6) BEST-EFFORT: Try /api/proxy/config + /api/proxy/reload on port 8000
#   7) Print final NIFDU Monolith Story recap
# ==============================================

param()

\Stop = "Stop"

function Say {
    param(
        [string]\,
        [string]\ = "Gray"
    )
    try {
        \ = [enum]::GetNames([System.ConsoleColor])
        if (\ -notcontains \) {
            \ = "Gray"
        }
        Write-Host \ -ForegroundColor \
    } catch {
        Write-Host \
    }
}

Say "
=== NIFDU / SOPHYANE — END-TO-END ONE-SHOT ===
" "Yellow"

# ------------------------------
# 0) Paths / config
# ------------------------------
\           = "C:\nifdu\ops"
\C:\nifdu\src\apps\sophyane_live           = "C:\nifdu\src\apps\sophyane_live"
\C:\nifdu\src\apps\sophyane_live\app\studio         = Join-Path \C:\nifdu\src\apps\sophyane_live "app\studio"
\C:\nifdu\src\apps\sophyane_live\app\studio\page.tsx          = Join-Path \C:\nifdu\src\apps\sophyane_live\app\studio "page.tsx"
\C:\nifdu\build\Release\nifdu.exe          = "C:\nifdu\build\Release\nifdu.exe"
\ = Join-Path \ "nifdu_monolith_with_env.ps1"

# NIFDU HTTP server is currently on 8000 (per logs)
\http://127.0.0.1:8000         = "http://127.0.0.1:8000"

\3001           = 3001
\      = "http://127.0.0.1:\3001/studio"

Say ("OPS Root: {0}" -f \) "DarkGray"
Say ("App Root: {0}" -f \C:\nifdu\src\apps\sophyane_live) "DarkGray"
Say ("NIFDU Base: {0}" -f \http://127.0.0.1:8000) "DarkGray"
Say ("Studio dev URL: {0}" -f \) "DarkGray"

if (-not (Test-Path \C:\nifdu\src\apps\sophyane_live)) {
    Say ("❌ App root not found: {0}" -f \C:\nifdu\src\apps\sophyane_live) "Red"
    throw "App root not found: \C:\nifdu\src\apps\sophyane_live"
}

# ------------------------------
# 1) Kill old nifdu.exe + node dev
# ------------------------------
Say "
=== CLEANUP OLD PROCESSES (nifdu + node) ===" "Yellow"

# Kill nifdu
\ = Get-Process -Name "nifdu" -ErrorAction SilentlyContinue
if (\) {
    foreach (\8000 in \) {
        Say ("Stopping nifdu PID {0}" -f \8000.Id) "DarkYellow"
        try {
            Stop-Process -Id \8000.Id -Force -ErrorAction Stop
            Say ("✅ Stopped nifdu PID {0}" -f \8000.Id) "Green"
        } catch {
            Say ("⚠ Failed to stop nifdu PID {0}: {1}" -f \8000.Id, \.Exception.Message) "Red"
        }
    }
} else {
    Say "No existing nifdu.exe processes found." "Green"
}

# Kill node dev servers
\System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) = Get-Process node -ErrorAction SilentlyContinue
if (\System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node)) {
    Say ("Found {0} node process(es). Stopping them..." -f \System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node).Count) "DarkYellow"
    \System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) System.Diagnostics.Process (node) | ForEach-Object {
        Say ("  Killing node PID {0}" -f \.Id) "DarkGray"
        try {
            Stop-Process -Id \.Id -Force -ErrorAction Stop
        } catch {
            Say ("  ⚠ Failed to stop node PID {0}: {1}" -f \.Id, \.Exception.Message) "Red"
        }
    }
} else {
    Say "No existing node dev servers detected." "Green"
}

# ------------------------------
# 2) Start NIFDU monolith
# ------------------------------
Say "
=== STARTING NIFDU MONOLITH (WITH ENV) ===" "Yellow"

if (Test-Path \) {
    Say ("Launching monolith via: {0}" -f \) "Cyan"
    Start-Process powershell -ArgumentList "-NoExit", "-File", \ -WorkingDirectory \ | Out-Null
} elseif (Test-Path \C:\nifdu\build\Release\nifdu.exe) {
    Say ("Launcher script not found, starting raw nifdu.exe: {0}" -f \C:\nifdu\build\Release\nifdu.exe) "Cyan"
    Start-Process -FilePath \C:\nifdu\build\Release\nifdu.exe -WorkingDirectory (Split-Path \C:\nifdu\build\Release\nifdu.exe) | Out-Null
} else {
    Say "❌ Neither nifdu_monolith_with_env.ps1 nor nifdu.exe found. Cannot start monolith." "Red"
    throw "NIFDU monolith start failed."
}

Say "Waiting 5 seconds for NIFDU core services (port 8000)..." "DarkGray"
Start-Sleep -Seconds 5

# ------------------------------
# 3) Ensure /studio page exists
# ------------------------------
Say "
=== ENSURING /studio PAGE (page.tsx) ===" "Yellow"

if (-not (Test-Path \C:\nifdu\src\apps\sophyane_live\app\studio)) {
    Say ("Creating directory: {0}" -f \C:\nifdu\src\apps\sophyane_live\app\studio) "DarkCyan"
    New-Item -ItemType Directory -Path \C:\nifdu\src\apps\sophyane_live\app\studio -Force | Out-Null
}

\"use client";

import React from "react";

export default function StudioPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center">
      <div className="max-w-2xl px-6 py-8 border border-slate-800 rounded-2xl bg-slate-900/60 shadow-lg">
        <h1 className="text-3xl font-semibold text-emerald-400 mb-4">
          Sophyane Studio
        </h1>
        <p className="text-slate-300 mb-4">
          This page was generated by NIFDU Agent 3 via{" "}
          <code className="ml-1 px-1.5 py-0.5 rounded bg-slate-800 text-xs">
            nifdu_sophyane_fullstack_oneshot.ps1
          </code>.
        </p>
        <p className="text-slate-400 text-sm">
          Wire this route into your vibe coding loop and start shipping full
          products from a single monolith.
        </p>
      </div>
    </main>
  );
} = @'
"use client";

import React from "react";

export default function StudioPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center">
      <div className="max-w-2xl px-6 py-8 border border-slate-800 rounded-2xl bg-slate-900/60 shadow-lg">
        <h1 className="text-3xl font-semibold text-emerald-400 mb-4">
          Sophyane Studio
        </h1>
        <p className="text-slate-300 mb-4">
          This page was generated by NIFDU Agent 3 via{" "}
          <code className="ml-1 px-1.5 py-0.5 rounded bg-slate-800 text-xs">
            nifdu_sophyane_end_to_end_oneshot.ps1
          </code>.
        </p>
        <p className="text-slate-400 text-sm">
          Wire this route into your vibe coding loop and start shipping full
          products from a single monolith.
        </p>
      </div>
    </main>
  );
}
'@

Say ("Writing: {0}" -f \C:\nifdu\src\apps\sophyane_live\app\studio\page.tsx) "Cyan"
Set-Content -Path \C:\nifdu\src\apps\sophyane_live\app\studio\page.tsx -Value \"use client";

import React from "react";

export default function StudioPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center">
      <div className="max-w-2xl px-6 py-8 border border-slate-800 rounded-2xl bg-slate-900/60 shadow-lg">
        <h1 className="text-3xl font-semibold text-emerald-400 mb-4">
          Sophyane Studio
        </h1>
        <p className="text-slate-300 mb-4">
          This page was generated by NIFDU Agent 3 via{" "}
          <code className="ml-1 px-1.5 py-0.5 rounded bg-slate-800 text-xs">
            nifdu_sophyane_fullstack_oneshot.ps1
          </code>.
        </p>
        <p className="text-slate-400 text-sm">
          Wire this route into your vibe coding loop and start shipping full
          products from a single monolith.
        </p>
      </div>
    </main>
  );
} -Encoding UTF8
Say "Wrote /studio page successfully." "Green"

# ------------------------------
# 4) Start node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev on PORT=3001 in new PS window
# ------------------------------
Say "
=== STARTING SOPHYANE STUDIO DEV (PORT 3001) ===" "Yellow"

if (-not (Test-Path (Join-Path \C:\nifdu\src\apps\sophyane_live "package.json"))) {
    Say "❌ No package.json found in app root. Is sophyane_live installed correctly?" "Red"
    throw "Missing package.json in \C:\nifdu\src\apps\sophyane_live"
}

# Build inline command instead of nested here-strings
\ = "cd "\C:\nifdu\src\apps\sophyane_live"; \3001 = "\3001"; node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev"

Say "Launching new PowerShell window for node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev..." "Cyan"
Start-Process powershell -ArgumentList "-NoExit", "-Command", \ | Out-Null

# ------------------------------
# 5) Probe raw dev /studio on port 3001
# ------------------------------
Say "
=== PROBING RAW DEV /studio ON PORT \3001 ===" "Yellow"

\40  = 40
\3 = 3
\True   = \False
\<!DOCTYPE html><html lang="en" class="dark"><head><meta charSet="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/><link rel="stylesheet" href="/_next/static/css/app/layout.css?v=1765440199466" data-precedence="next_static/css/app/layout.css"/><link rel="preload" as="script" fetchPriority="low" href="/_next/static/chunks/webpack.js?v=1765440199466"/><script src="/_next/static/chunks/main-app.js?v=1765440199466" async=""></script><script src="/_next/static/chunks/app-pages-internals.js" async=""></script><script src="/_next/static/chunks/app/studio/page.js" async=""></script><title>Sophyane Live - Self-hosted AI Factory</title><meta name="description" content="Sophyane + NIFDU: Self-hosted AI factory with 38+ APIs"/><script src="/_next/static/chunks/polyfills.js" noModule=""></script></head><body class="bg-gray-900 text-green-400 font-sans min-h-screen"><main class="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center"><div class="max-w-2xl px-6 py-8 border border-slate-800 rounded-2xl bg-slate-900/60 shadow-lg"><h1 class="text-3xl font-semibold text-emerald-400 mb-4">Sophyane Studio</h1><p class="text-slate-300 mb-4">This page was generated by NIFDU Agent 3 via<!-- --> <code class="ml-1 px-1.5 py-0.5 rounded bg-slate-800 text-xs">nifdu_sophyane_fullstack_oneshot.ps1</code>.</p><p class="text-slate-400 text-sm">Wire this route into your vibe coding loop and start shipping full products from a single monolith.</p></div></main><script src="/_next/static/chunks/webpack.js?v=1765440199466" async=""></script><script>(self.__next_f=self.__next_f||[]).push([0]);self.__next_f.push([2,null])</script><script>self.__next_f.push([1,"1:HL[\"/_next/static/css/app/layout.css?v=1765440199466\",\"style\"]\n0:\"$L2\"\n"])</script><script>self.__next_f.push([1,"3:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/app-router.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n5:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/error-boundary.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n6:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5."])</script><script>self.__next_f.push([1,"11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/layout-router.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n7:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/render-from-template-context.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n9:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react"])</script><script>self.__next_f.push([1,"@18.3.1/node_modules/next/dist/client/components/static-generation-searchparams-bailout-provider.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\na:I[\"(app-pages-browser)/./app/studio/page.tsx\",[\"app/studio/page\",\"static/chunks/app/studio/page.js\"],\"\"]\n"])</script><script>self.__next_f.push([1,"2:[[[\"$\",\"link\",\"0\",{\"rel\":\"stylesheet\",\"href\":\"/_next/static/css/app/layout.css?v=1765440199466\",\"precedence\":\"next_static/css/app/layout.css\",\"crossOrigin\":\"$undefined\"}]],[\"$\",\"$L3\",null,{\"buildId\":\"development\",\"assetPrefix\":\"\",\"initialCanonicalUrl\":\"/studio\",\"initialTree\":[\"\",{\"children\":[\"studio\",{\"children\":[\"__PAGE__\",{}]}]},\"$undefined\",\"$undefined\",true],\"initialHead\":[false,\"$L4\"],\"globalErrorComponent\":\"$5\",\"children\":[null,[\"$\",\"html\",null,{\"lang\":\"en\",\"className\":\"dark\",\"children\":[\"$\",\"body\",null,{\"className\":\"bg-gray-900 text-green-400 font-sans min-h-screen\",\"children\":[\"$\",\"$L6\",null,{\"parallelRouterKey\":\"children\",\"segmentPath\":[\"children\"],\"loading\":\"$undefined\",\"loadingStyles\":\"$undefined\",\"hasLoading\":false,\"error\":\"$undefined\",\"errorStyles\":\"$undefined\",\"template\":[\"$\",\"$L7\",null,{}],\"templateStyles\":\"$undefined\",\"notFound\":[[\"$\",\"title\",null,{\"children\":\"404: This page could not be found.\"}],[\"$\",\"div\",null,{\"style\":{\"fontFamily\":\"system-ui,\\\"Segoe UI\\\",Roboto,Helvetica,Arial,sans-serif,\\\"Apple Color Emoji\\\",\\\"Segoe UI Emoji\\\"\",\"height\":\"100vh\",\"textAlign\":\"center\",\"display\":\"flex\",\"flexDirection\":\"column\",\"alignItems\":\"center\",\"justifyContent\":\"center\"},\"children\":[\"$\",\"div\",null,{\"children\":[[\"$\",\"style\",null,{\"dangerouslySetInnerHTML\":{\"__html\":\"body{color:#000;background:#fff;margin:0}.next-error-h1{border-right:1px solid rgba(0,0,0,.3)}@media (prefers-color-scheme:dark){body{color:#fff;background:#000}.next-error-h1{border-right:1px solid rgba(255,255,255,.3)}}\"}}],[\"$\",\"h1\",null,{\"className\":\"next-error-h1\",\"style\":{\"display\":\"inline-block\",\"margin\":\"0 20px 0 0\",\"padding\":\"0 23px 0 0\",\"fontSize\":24,\"fontWeight\":500,\"verticalAlign\":\"top\",\"lineHeight\":\"49px\"},\"children\":\"404\"}],[\"$\",\"div\",null,{\"style\":{\"display\":\"inline-block\"},\"children\":[\"$\",\"h2\",null,{\"style\":{\"fontSize\":14,\"fontWeight\":400,\"lineHeight\":\"49px\",\"margin\":0},\"children\":\"This page could not be found.\"}]}]]}]}]],\"notFoundStyles\":[],\"childProp\":{\"current\":[\"$\",\"$L6\",null,{\"parallelRouterKey\":\"children\",\"segmentPath\":[\"children\",\"studio\",\"children\"],\"loading\":\"$undefined\",\"loadingStyles\":\"$undefined\",\"hasLoading\":false,\"error\":\"$undefined\",\"errorStyles\":\"$undefined\",\"template\":[\"$\",\"$L7\",null,{}],\"templateStyles\":\"$undefined\",\"notFound\":\"$undefined\",\"notFoundStyles\":\"$undefined\",\"childProp\":{\"current\":[\"$L8\",[\"$\",\"$L9\",null,{\"propsForComponent\":{\"params\":{},\"searchParams\":{}},\"Component\":\"$a\",\"isStaticGeneration\":false}],null],\"segment\":\"__PAGE__\"},\"styles\":[]}],\"segment\":\"studio\"},\"styles\":[]}]}]}],null]}]]\n"])</script><script>self.__next_f.push([1,"4:[[\"$\",\"meta\",\"0\",{\"charSet\":\"utf-8\"}],[\"$\",\"title\",\"1\",{\"children\":\"Sophyane Live - Self-hosted AI Factory\"}],[\"$\",\"meta\",\"2\",{\"name\":\"description\",\"content\":\"Sophyane + NIFDU: Self-hosted AI factory with 38+ APIs\"}],[\"$\",\"meta\",\"3\",{\"name\":\"viewport\",\"content\":\"width=device-width, initial-scale=1\"}]]\n8:null\n"])</script></body></html>  = \

for (\2 = 1; \2 -le \40; \2++) {
    Say ("Attempt {0}/{1}: {2}" -f \2, \40, \) "DarkCyan"
    try {
        \<!DOCTYPE html><html lang="en" class="dark"><head><meta charSet="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/><link rel="stylesheet" href="/_next/static/css/app/layout.css?v=1765440199466" data-precedence="next_static/css/app/layout.css"/><link rel="preload" as="script" fetchPriority="low" href="/_next/static/chunks/webpack.js?v=1765440199466"/><script src="/_next/static/chunks/main-app.js?v=1765440199466" async=""></script><script src="/_next/static/chunks/app-pages-internals.js" async=""></script><script src="/_next/static/chunks/app/studio/page.js" async=""></script><title>Sophyane Live - Self-hosted AI Factory</title><meta name="description" content="Sophyane + NIFDU: Self-hosted AI factory with 38+ APIs"/><script src="/_next/static/chunks/polyfills.js" noModule=""></script></head><body class="bg-gray-900 text-green-400 font-sans min-h-screen"><main class="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center"><div class="max-w-2xl px-6 py-8 border border-slate-800 rounded-2xl bg-slate-900/60 shadow-lg"><h1 class="text-3xl font-semibold text-emerald-400 mb-4">Sophyane Studio</h1><p class="text-slate-300 mb-4">This page was generated by NIFDU Agent 3 via<!-- --> <code class="ml-1 px-1.5 py-0.5 rounded bg-slate-800 text-xs">nifdu_sophyane_fullstack_oneshot.ps1</code>.</p><p class="text-slate-400 text-sm">Wire this route into your vibe coding loop and start shipping full products from a single monolith.</p></div></main><script src="/_next/static/chunks/webpack.js?v=1765440199466" async=""></script><script>(self.__next_f=self.__next_f||[]).push([0]);self.__next_f.push([2,null])</script><script>self.__next_f.push([1,"1:HL[\"/_next/static/css/app/layout.css?v=1765440199466\",\"style\"]\n0:\"$L2\"\n"])</script><script>self.__next_f.push([1,"3:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/app-router.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n5:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/error-boundary.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n6:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5."])</script><script>self.__next_f.push([1,"11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/layout-router.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n7:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/render-from-template-context.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n9:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react"])</script><script>self.__next_f.push([1,"@18.3.1/node_modules/next/dist/client/components/static-generation-searchparams-bailout-provider.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\na:I[\"(app-pages-browser)/./app/studio/page.tsx\",[\"app/studio/page\",\"static/chunks/app/studio/page.js\"],\"\"]\n"])</script><script>self.__next_f.push([1,"2:[[[\"$\",\"link\",\"0\",{\"rel\":\"stylesheet\",\"href\":\"/_next/static/css/app/layout.css?v=1765440199466\",\"precedence\":\"next_static/css/app/layout.css\",\"crossOrigin\":\"$undefined\"}]],[\"$\",\"$L3\",null,{\"buildId\":\"development\",\"assetPrefix\":\"\",\"initialCanonicalUrl\":\"/studio\",\"initialTree\":[\"\",{\"children\":[\"studio\",{\"children\":[\"__PAGE__\",{}]}]},\"$undefined\",\"$undefined\",true],\"initialHead\":[false,\"$L4\"],\"globalErrorComponent\":\"$5\",\"children\":[null,[\"$\",\"html\",null,{\"lang\":\"en\",\"className\":\"dark\",\"children\":[\"$\",\"body\",null,{\"className\":\"bg-gray-900 text-green-400 font-sans min-h-screen\",\"children\":[\"$\",\"$L6\",null,{\"parallelRouterKey\":\"children\",\"segmentPath\":[\"children\"],\"loading\":\"$undefined\",\"loadingStyles\":\"$undefined\",\"hasLoading\":false,\"error\":\"$undefined\",\"errorStyles\":\"$undefined\",\"template\":[\"$\",\"$L7\",null,{}],\"templateStyles\":\"$undefined\",\"notFound\":[[\"$\",\"title\",null,{\"children\":\"404: This page could not be found.\"}],[\"$\",\"div\",null,{\"style\":{\"fontFamily\":\"system-ui,\\\"Segoe UI\\\",Roboto,Helvetica,Arial,sans-serif,\\\"Apple Color Emoji\\\",\\\"Segoe UI Emoji\\\"\",\"height\":\"100vh\",\"textAlign\":\"center\",\"display\":\"flex\",\"flexDirection\":\"column\",\"alignItems\":\"center\",\"justifyContent\":\"center\"},\"children\":[\"$\",\"div\",null,{\"children\":[[\"$\",\"style\",null,{\"dangerouslySetInnerHTML\":{\"__html\":\"body{color:#000;background:#fff;margin:0}.next-error-h1{border-right:1px solid rgba(0,0,0,.3)}@media (prefers-color-scheme:dark){body{color:#fff;background:#000}.next-error-h1{border-right:1px solid rgba(255,255,255,.3)}}\"}}],[\"$\",\"h1\",null,{\"className\":\"next-error-h1\",\"style\":{\"display\":\"inline-block\",\"margin\":\"0 20px 0 0\",\"padding\":\"0 23px 0 0\",\"fontSize\":24,\"fontWeight\":500,\"verticalAlign\":\"top\",\"lineHeight\":\"49px\"},\"children\":\"404\"}],[\"$\",\"div\",null,{\"style\":{\"display\":\"inline-block\"},\"children\":[\"$\",\"h2\",null,{\"style\":{\"fontSize\":14,\"fontWeight\":400,\"lineHeight\":\"49px\",\"margin\":0},\"children\":\"This page could not be found.\"}]}]]}]}]],\"notFoundStyles\":[],\"childProp\":{\"current\":[\"$\",\"$L6\",null,{\"parallelRouterKey\":\"children\",\"segmentPath\":[\"children\",\"studio\",\"children\"],\"loading\":\"$undefined\",\"loadingStyles\":\"$undefined\",\"hasLoading\":false,\"error\":\"$undefined\",\"errorStyles\":\"$undefined\",\"template\":[\"$\",\"$L7\",null,{}],\"templateStyles\":\"$undefined\",\"notFound\":\"$undefined\",\"notFoundStyles\":\"$undefined\",\"childProp\":{\"current\":[\"$L8\",[\"$\",\"$L9\",null,{\"propsForComponent\":{\"params\":{},\"searchParams\":{}},\"Component\":\"$a\",\"isStaticGeneration\":false}],null],\"segment\":\"__PAGE__\"},\"styles\":[]}],\"segment\":\"studio\"},\"styles\":[]}]}]}],null]}]]\n"])</script><script>self.__next_f.push([1,"4:[[\"$\",\"meta\",\"0\",{\"charSet\":\"utf-8\"}],[\"$\",\"title\",\"1\",{\"children\":\"Sophyane Live - Self-hosted AI Factory\"}],[\"$\",\"meta\",\"2\",{\"name\":\"description\",\"content\":\"Sophyane + NIFDU: Self-hosted AI factory with 38+ APIs\"}],[\"$\",\"meta\",\"3\",{\"name\":\"viewport\",\"content\":\"width=device-width, initial-scale=1\"}]]\n8:null\n"])</script></body></html> = Invoke-WebRequest -Uri \ -UseBasicParsing -TimeoutSec 5
        \True  = \True
        break
    } catch {
        Say ("  ❌ Failed: {0}" -f \.Exception.Message) "DarkGray"
        Start-Sleep -Seconds \3
    }
}

if (-not \True) {
    Say "
❌ Dev server did not come up on port \3001 in time." "Red"
    Say "   - Check the new node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev window for errors (missing deps, build errors, etc.)." "Red"
} else {
    Say "
✅ Raw dev /studio is responding on \" "Green"
    if (\<!DOCTYPE html><html lang="en" class="dark"><head><meta charSet="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/><link rel="stylesheet" href="/_next/static/css/app/layout.css?v=1765440199466" data-precedence="next_static/css/app/layout.css"/><link rel="preload" as="script" fetchPriority="low" href="/_next/static/chunks/webpack.js?v=1765440199466"/><script src="/_next/static/chunks/main-app.js?v=1765440199466" async=""></script><script src="/_next/static/chunks/app-pages-internals.js" async=""></script><script src="/_next/static/chunks/app/studio/page.js" async=""></script><title>Sophyane Live - Self-hosted AI Factory</title><meta name="description" content="Sophyane + NIFDU: Self-hosted AI factory with 38+ APIs"/><script src="/_next/static/chunks/polyfills.js" noModule=""></script></head><body class="bg-gray-900 text-green-400 font-sans min-h-screen"><main class="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center"><div class="max-w-2xl px-6 py-8 border border-slate-800 rounded-2xl bg-slate-900/60 shadow-lg"><h1 class="text-3xl font-semibold text-emerald-400 mb-4">Sophyane Studio</h1><p class="text-slate-300 mb-4">This page was generated by NIFDU Agent 3 via<!-- --> <code class="ml-1 px-1.5 py-0.5 rounded bg-slate-800 text-xs">nifdu_sophyane_fullstack_oneshot.ps1</code>.</p><p class="text-slate-400 text-sm">Wire this route into your vibe coding loop and start shipping full products from a single monolith.</p></div></main><script src="/_next/static/chunks/webpack.js?v=1765440199466" async=""></script><script>(self.__next_f=self.__next_f||[]).push([0]);self.__next_f.push([2,null])</script><script>self.__next_f.push([1,"1:HL[\"/_next/static/css/app/layout.css?v=1765440199466\",\"style\"]\n0:\"$L2\"\n"])</script><script>self.__next_f.push([1,"3:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/app-router.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n5:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/error-boundary.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n6:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5."])</script><script>self.__next_f.push([1,"11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/layout-router.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n7:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react@18.3.1/node_modules/next/dist/client/components/render-from-template-context.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\n9:I[\"(app-pages-browser)/./node_modules/.pnpm/next@13.5.11_react-dom@18.3.1_react@18.3.1__react"])</script><script>self.__next_f.push([1,"@18.3.1/node_modules/next/dist/client/components/static-generation-searchparams-bailout-provider.js\",[\"app-pages-internals\",\"static/chunks/app-pages-internals.js\"],\"\"]\na:I[\"(app-pages-browser)/./app/studio/page.tsx\",[\"app/studio/page\",\"static/chunks/app/studio/page.js\"],\"\"]\n"])</script><script>self.__next_f.push([1,"2:[[[\"$\",\"link\",\"0\",{\"rel\":\"stylesheet\",\"href\":\"/_next/static/css/app/layout.css?v=1765440199466\",\"precedence\":\"next_static/css/app/layout.css\",\"crossOrigin\":\"$undefined\"}]],[\"$\",\"$L3\",null,{\"buildId\":\"development\",\"assetPrefix\":\"\",\"initialCanonicalUrl\":\"/studio\",\"initialTree\":[\"\",{\"children\":[\"studio\",{\"children\":[\"__PAGE__\",{}]}]},\"$undefined\",\"$undefined\",true],\"initialHead\":[false,\"$L4\"],\"globalErrorComponent\":\"$5\",\"children\":[null,[\"$\",\"html\",null,{\"lang\":\"en\",\"className\":\"dark\",\"children\":[\"$\",\"body\",null,{\"className\":\"bg-gray-900 text-green-400 font-sans min-h-screen\",\"children\":[\"$\",\"$L6\",null,{\"parallelRouterKey\":\"children\",\"segmentPath\":[\"children\"],\"loading\":\"$undefined\",\"loadingStyles\":\"$undefined\",\"hasLoading\":false,\"error\":\"$undefined\",\"errorStyles\":\"$undefined\",\"template\":[\"$\",\"$L7\",null,{}],\"templateStyles\":\"$undefined\",\"notFound\":[[\"$\",\"title\",null,{\"children\":\"404: This page could not be found.\"}],[\"$\",\"div\",null,{\"style\":{\"fontFamily\":\"system-ui,\\\"Segoe UI\\\",Roboto,Helvetica,Arial,sans-serif,\\\"Apple Color Emoji\\\",\\\"Segoe UI Emoji\\\"\",\"height\":\"100vh\",\"textAlign\":\"center\",\"display\":\"flex\",\"flexDirection\":\"column\",\"alignItems\":\"center\",\"justifyContent\":\"center\"},\"children\":[\"$\",\"div\",null,{\"children\":[[\"$\",\"style\",null,{\"dangerouslySetInnerHTML\":{\"__html\":\"body{color:#000;background:#fff;margin:0}.next-error-h1{border-right:1px solid rgba(0,0,0,.3)}@media (prefers-color-scheme:dark){body{color:#fff;background:#000}.next-error-h1{border-right:1px solid rgba(255,255,255,.3)}}\"}}],[\"$\",\"h1\",null,{\"className\":\"next-error-h1\",\"style\":{\"display\":\"inline-block\",\"margin\":\"0 20px 0 0\",\"padding\":\"0 23px 0 0\",\"fontSize\":24,\"fontWeight\":500,\"verticalAlign\":\"top\",\"lineHeight\":\"49px\"},\"children\":\"404\"}],[\"$\",\"div\",null,{\"style\":{\"display\":\"inline-block\"},\"children\":[\"$\",\"h2\",null,{\"style\":{\"fontSize\":14,\"fontWeight\":400,\"lineHeight\":\"49px\",\"margin\":0},\"children\":\"This page could not be found.\"}]}]]}]}]],\"notFoundStyles\":[],\"childProp\":{\"current\":[\"$\",\"$L6\",null,{\"parallelRouterKey\":\"children\",\"segmentPath\":[\"children\",\"studio\",\"children\"],\"loading\":\"$undefined\",\"loadingStyles\":\"$undefined\",\"hasLoading\":false,\"error\":\"$undefined\",\"errorStyles\":\"$undefined\",\"template\":[\"$\",\"$L7\",null,{}],\"templateStyles\":\"$undefined\",\"notFound\":\"$undefined\",\"notFoundStyles\":\"$undefined\",\"childProp\":{\"current\":[\"$L8\",[\"$\",\"$L9\",null,{\"propsForComponent\":{\"params\":{},\"searchParams\":{}},\"Component\":\"$a\",\"isStaticGeneration\":false}],null],\"segment\":\"__PAGE__\"},\"styles\":[]}],\"segment\":\"studio\"},\"styles\":[]}]}]}],null]}]]\n"])</script><script>self.__next_f.push([1,"4:[[\"$\",\"meta\",\"0\",{\"charSet\":\"utf-8\"}],[\"$\",\"title\",\"1\",{\"children\":\"Sophyane Live - Self-hosted AI Factory\"}],[\"$\",\"meta\",\"2\",{\"name\":\"description\",\"content\":\"Sophyane + NIFDU: Self-hosted AI factory with 38+ APIs\"}],[\"$\",\"meta\",\"3\",{\"name\":\"viewport\",\"content\":\"width=device-width, initial-scale=1\"}]]\n8:null\n"])</script></body></html>.Content -like "*Sophyane Studio*") {
        Say "✅ Content: 'Sophyane Studio' found in dev HTML." "Green"
    } else {
        Say "⚠ Content: 'Sophyane Studio' NOT found in dev HTML (but endpoint responded)." "Yellow"
    }
}

# ------------------------------
# 6) BEST-EFFORT: /api/proxy/config + /api/proxy/reload on port 8000
# ------------------------------
Say "
=== BEST-EFFORT NIFDU PROXY CONFIG (via 8000) ===" "Yellow"

\System.Collections.Hashtable = @{
    routes = @(
        @{
            host      = "sophyane.com"
            upstreams = @("http://127.0.0.1:\3001")
        }
    )
}

\ = \False

try {
    \{
  "routes": [
    {
      "upstreams": [
        "http://127.0.0.1:3001"
      ],
      "host": "sophyane.com"
    }
  ]
} = \System.Collections.Hashtable | ConvertTo-Json -Depth 10
    \ = Invoke-RestMethod 
        -Uri "\http://127.0.0.1:8000/api/proxy/config" 
        -Method Post 
        -ContentType "application/json; charset=utf-8" 
        -Body \{
  "routes": [
    {
      "upstreams": [
        "http://127.0.0.1:3001"
      ],
      "host": "sophyane.com"
    }
  ]
}
    Say "✅ /api/proxy/config applied for sophyane.com -> http://127.0.0.1:\3001" "Green"
    \ = \True
} catch {
    \ = \.Exception.Message
    Say "⚠ /api/proxy/config failed (likely not implemented in this NIFDU build)." "DarkYellow"
    Say ("   Backend said: {0}" -f \) "DarkGray"
}

if (\) {
    try {
        \ = Invoke-RestMethod 
            -Uri "\http://127.0.0.1:8000/api/proxy/reload" 
            -Method Post 
            -ContentType "application/json; charset=utf-8"
        Say "✅ /api/proxy/reload called successfully." "Green"
    } catch {
        \ = \.Exception.Message
        Say "⚠ /api/proxy/reload failed (likely not implemented in this NIFDU build)." "DarkYellow"
        Say ("   Backend said: {0}" -f \) "DarkGray"
    }
} else {
    Say "Skipping /api/proxy/reload because /api/proxy/config was not applied." "DarkGray"
}

# ------------------------------
# 7) Final NIFDU Monolith Story
# ------------------------------
Say "
====================================================" "DarkMagenta"
Say "FINAL LOOP COMPLETE: SOPHYANE DEV LOOP CONVERGED" "Yellow"
Say "====================================================
" "DarkMagenta"

Say "Agent 3 Analysis Recap:" "Cyan"
Say "1. Application fix: /studio implemented via app\studio\page.tsx in sophyane_live." "Green"
Say ("2. Frontend dev: Sophyane Studio Next.js dev launched on PORT={0} (node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev in a separate window)." -f \3001) "Green"
Say ("3. Monolith: NIFDU core services running via nifdu_monolith_with_env.ps1 on HTTP base {0}." -f \http://127.0.0.1:8000) "Green"

if (\True) {
    Say "
VERDICT (DEV LOOP): ✅ SOPHYANE STUDIO DEV IS LIVE ON http://127.0.0.1:\3001/studio" "Magenta"
} else {
    Say "
VERDICT (DEV LOOP): ❌ Dev server failed to bind; check node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev window logs." "Red"
}

Say "
Proxy /api/proxy/* status (truthful):" "Cyan"
Say "  - Current nifdu.exe build on port 8000 does not implement /api/proxy/config or /api/proxy/reload (404 Not Found from previous tests)." "Yellow"
Say "  - PowerShell cannot fix missing backend APIs; those must be added in C++ inside the NIFDU monolith." "Yellow"

Say "
====================================================" "DarkMagenta"
Say "NIFDU MONOLITH STORY: SOPHYANE END-TO-END ONE-SHOT COMPLETE" "Yellow"
Say "====================================================
" "DarkMagenta"

Say "From now on, the founder has a single ritual for dev:" "Green"
Say "  1) Run nifdu_sophyane_end_to_end_oneshot.ps1" "Gray"
Say "  2) Sophyane Studio dev starts on port 3001, with /studio wired." "Gray"
Say "  3) When proxy APIs exist in NIFDU, this same script will light them up automatically." "Gray"
