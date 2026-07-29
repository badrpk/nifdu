param()

$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$Text,
        [string]$Color = "Gray"
    )
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

$appRoot  = "C:\nifdu\src\apps\sophyane_live"
$pagesDir = Join-Path $appRoot "pages"
$pagePath = Join-Path $pagesDir "studio.tsx"

Say "`n=== SOPHYANE — MAKE /pages/studio.tsx (FALLBACK) ===`n" "Yellow"
Say ("App root: {0}" -f $appRoot) "Cyan"

if (-not (Test-Path $appRoot)) {
    Say ("ERROR: App root not found: {0}" -f $appRoot) "Red"
    throw "App root not found: $appRoot"
}

if (-not (Test-Path $pagesDir)) {
    Say ("Creating pages directory: {0}" -f $pagesDir) "DarkCyan"
    New-Item -ItemType Directory -Path $pagesDir -Force | Out-Null
}

# IMPORTANT:
# This is a PowerShell here-string @" ... "@.
# PowerShell does NOT parse any of the React/JSX inside.
$pageContent = @"
import React from "react";

export default function StudioPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center">
      <div className="max-w-2xl px-6 py-8 border border-slate-800 rounded-2xl bg-slate-900/60 shadow-lg">
        <h1 className="text-3xl font-semibold text-emerald-400 mb-4">
          Sophyane Studio (pages router)
        </h1>
        <p className="text-slate-300 mb-4">
          This /studio route is served from pages/studio.tsx as a fallback,
          so NIFDU and Sophyane stay unblocked.
        </p>
      </div>
    </main>
  );
}
"@

Say ("Writing: {0}" -f $pagePath) "Cyan"
Set-Content -Path $pagePath -Value $pageContent -Encoding UTF8
Say "Wrote /pages/studio.tsx successfully." "Green"
