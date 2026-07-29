param(
  [string]$Contract = "C:\nifdu\ops\contracts\build_run_preview_contract.json"
)

$ErrorActionPreference="Continue"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

if(!(Test-Path $Contract)){ throw "Missing contract: $Contract" }
$cfg = Get-Content $Contract -Raw -Encoding UTF8 | ConvertFrom-Json

# Build a simple routes payload that NIFDU can consume (even if stubbed today)
# Route:  {domain}{preview.path} -> preview.upstream , stripPrefix
$payload = @{
  domain = $cfg.domain
  routes = @(
    @{
      id = "vibe_preview"
      match = @{ path_prefix = $cfg.preview.path }
      upstream = $cfg.preview.upstream
      strip_prefix = $cfg.preview.stripPrefix
    }
  )
} | ConvertTo-Json -Depth 10

$tmp = Join-Path "C:\nifdu\runtime" "proxy_routes_contract.json"
[IO.File]::WriteAllText($tmp, $payload, (New-Object System.Text.UTF8Encoding($false)))

Say "
=== CONTRACT PROXY APPLY (best-effort) ===" Yellow
Say ("Routes file: " + $tmp) DarkGray
Say ("POST: " + $cfg.proxyApis.routes) DarkGray
Say ("RELOAD: " + $cfg.proxyApis.reload) DarkGray

# Try POST routes
try{
  cmd.exe /c ("curl.exe -sS -X POST --max-time 4 -H ""Content-Type: application/json"" --data-binary @""" + $tmp + """ """ + $cfg.proxyApis.routes + """") | Out-Host
} catch {
  Say ("WARN: routes apply failed: " + $_.Exception.Message) DarkYellow
}

# Try reload
try{
  cmd.exe /c ("curl.exe -sS -X POST --max-time 4 """ + $cfg.proxyApis.reload + """") | Out-Host
} catch {
  Say ("WARN: proxy reload failed: " + $_.Exception.Message) DarkYellow
}

Say "OK: proxy apply done (or queued if APIs are stubs)." Green