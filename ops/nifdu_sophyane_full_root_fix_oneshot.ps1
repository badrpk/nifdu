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

# ---------------------------------------------------------
# 1) Ensure Sophyane webroot + index.html
# ---------------------------------------------------------
$rootDir   = "C:\webroot\nifdu.com\www"
$indexPath = Join-Path $rootDir "index.html"

Say ""
Say "=== NIFDU / SOPHYANE FULL ROOT FIX ONE-SHOT ===" "Yellow"

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
        -> <a href="/apps/dogs_karachi_site/">Dog Adoption Karachi landing page</a>
      </div>
      <div>
        -> Future: Sophyane vibe coding UI will live here.
      </div>
    </div>
  </div>
</body>
</html>
"@

Say ("Writing index.html to: {0}" -f $indexPath) "Cyan"
Set-Content -Path $indexPath -Value $html -Encoding UTF8

# ---------------------------------------------------------
# 2) Patch router.cpp sanitize_path
# ---------------------------------------------------------
$routerPath = "C:\nifdu\src\http\router.cpp"
if (-not (Test-Path $routerPath)) {
    throw "router.cpp not found at $routerPath"
}

Say ("Patching sanitize_path in: {0}" -f $routerPath) "Yellow"

$routerContent = Get-Content -Path $routerPath -Raw

$pattern = 'std::string\s+sanitize_path\s*\([^)]*\)\s*\{.*?\}'
$replacement = @"
std::string sanitize_path(const std::string& path)
{
    // Very small, safe normalizer:
    // - "/" or "" -> "index.html"
    // - strip leading '/'
    // - reject ".." segments
    std::string p = path;

    // Special-case root -> index.html
    if (p.empty() || p == "/") {
        return std::string("index.html");
    }

    if (!p.empty() && p[0] == '/') {
        p.erase(0, 1);
    }

    // If someone tries "../../", just block by returning empty
    if (p.find("..") != std::string::npos) {
        return std::string();
    }
    return p;
}
"@

$newRouterContent = [System.Text.RegularExpressions.Regex]::Replace(
    $routerContent,
    $pattern,
    $replacement,
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

if ($newRouterContent -eq $routerContent) {
    throw "sanitize_path pattern not found or not replaced. Check router.cpp manually."
}

Set-Content -Path $routerPath -Value $newRouterContent -Encoding UTF8
Say "sanitize_path patched successfully." "Green"

# ---------------------------------------------------------
# 3) Rebuild NIFDU (Release)
# ---------------------------------------------------------
$buildDir = "C:\nifdu\build"
if (-not (Test-Path $buildDir)) {
    throw "Build directory not found: $buildDir"
}

Say ("Building NIFDU in: {0}" -f $buildDir) "Yellow"
Push-Location $buildDir
cmake --build . --config Release
Pop-Location

# ---------------------------------------------------------
# 4) Restart nifdu.exe
# ---------------------------------------------------------
Say "Restarting nifdu.exe..." "Yellow"
Stop-Process -Name nifdu -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
$exePath = "C:\nifdu\build\Release\nifdu.exe"
if (-not (Test-Path $exePath)) {
    throw "nifdu.exe not found at $exePath"
}
Start-Process $exePath
Start-Sleep -Seconds 2

# ---------------------------------------------------------
# 5) HTTP/HTTPS smoke tests via sophyane.com
# ---------------------------------------------------------
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.SecurityProtocolType]::Tls12 -bor
    [System.Net.SecurityProtocolType]::Tls11 -bor
    [System.Net.SecurityProtocolType]::Tls

function Get-BodySnippet {
    param(
        [Parameter(Mandatory = $true)]
        $Content,
        [int]$MaxLen = 120
    )

    if ($null -eq $Content) { return "" }

    if ($Content -is [byte[]]) {
        $text = [System.Text.Encoding]::UTF8.GetString($Content)
    } else {
        $text = [string]$Content
    }

    if ($text.Length -gt $MaxLen) {
        return $text.Substring(0, $MaxLen)
    }
    return $text
}

Say "`n--- HTTP 80 (NIFDU) - FOLLOW REDIRECTS ---`n" "Yellow"
try {
    $resHttp = Invoke-WebRequest -Uri 'http://sophyane.com/' -UseBasicParsing

    [PSCustomObject]@{
        Kind     = "HTTP"
        FinalUri = $resHttp.BaseResponse.ResponseUri.AbsoluteUri
        Code     = $resHttp.StatusCode
        Snippet  = Get-BodySnippet -Content $resHttp.Content -MaxLen 120
    } | Format-List
} catch {
    Say ("HTTP check failed: {0}" -f $_) "Red"
}

Say "`n--- HTTPS 443 (CADDY -> NIFDU) ---`n" "Yellow"
try {
    $resHttps = Invoke-WebRequest -Uri 'https://sophyane.com/' -UseBasicParsing

    [PSCustomObject]@{
        Kind     = "HTTPS"
        FinalUri = $resHttps.BaseResponse.ResponseUri.AbsoluteUri
        Code     = $resHttps.StatusCode
        Snippet  = Get-BodySnippet -Content $resHttps.Content -MaxLen 120
    } | Format-List
} catch {
    Say ("HTTPS check failed: {0}" -f $_) "Red"
}

Say "`n=== DONE: Sophyane root + router fix applied ===`n" "Green"
