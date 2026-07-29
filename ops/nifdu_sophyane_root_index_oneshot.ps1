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

$rootDir   = "C:\webroot\nifdu.com\www"
$indexPath = Join-Path $rootDir "index.html"

Say ""
Say "=== NIFDU / SOPHYANE ROOT INDEX ONE-SHOT ===" "Yellow"

if (-not (Test-Path $rootDir)) {
    Say ("Creating webroot: {0}" -f $rootDir) "DarkCyan"
    New-Item -ItemType Directory -Path $rootDir -Force | Out-Null
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Sophyane · NIFDU Vibe Coding</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body {
      margin: 0;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
      background: radial-gradient(circle at top left, #0f172a, #020617);
      color: #e5e7eb;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .shell {
      max-width: 720px;
      padding: 32px 24px;
      background: rgba(15,23,42,0.92);
      border-radius: 18px;
      border: 1px solid #1f2937;
      box-shadow: 0 18px 45px rgba(0,0,0,0.7);
    }
    h1 {
      margin: 0 0 8px;
      font-size: 28px;
      color: #a5b4fc;
    }
    p {
      margin: 0 0 16px;
      color: #9ca3af;
      font-size: 14px;
    }
    a {
      color: #22c55e;
      text-decoration: none;
      font-weight: 600;
    }
    a:hover {
      text-decoration: underline;
    }
    .links {
      margin-top: 12px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      font-size: 12px;
      background: #020617;
      padding: 2px 4px;
      border-radius: 4px;
      border: 1px solid #111827;
    }
  </style>
</head>
<body>
  <div class="shell">
    <h1>Sophyane is live on NIFDU</h1>
    <p>
      You are hitting NIFDU through Caddy at
      <code>https://sophyane.com/</code>.
    </p>
    <div class="links">
      <div>
        ➜ <a href="/apps/dogs_karachi_site/">Dog Adoption Karachi landing page</a>
      </div>
      <div>
        ➜ Future: Sophyane vibe coding UI will live here.
      </div>
    </div>
  </div>
</body>
</html>
"@

Say ("Writing index.html to: {0}" -f $indexPath) "Cyan"
Set-Content -Path $indexPath -Value $html -Encoding UTF8

Say ""
Say "=== DONE: Sophyane root index written ===" "Yellow"
Say ""
