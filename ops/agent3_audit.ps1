param(
  [string]$Repo      = "C:\nifdu",
  [string]$SrcRoot   = "C:\nifdu\src",
  [string]$OpsRoot   = "C:\nifdu\ops",
  [string]$WebRoot   = "C:\webroot",
  [string]$Runtime   = "C:\nifdu\runtime",
  [string]$BaseUrl   = "http://127.0.0.1",
  [int]$TimeoutSec   = 2
)

$ErrorActionPreference="Continue"

function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }
function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function Curl-Json {
  param([string]$Url)
  try { $o = & curl.exe -sS --max-time $TimeoutSec $Url 2>$null; if(!$o){ return $null }; return $o } catch { return $null }
}
function Curl-Head {
  param([string]$Url)
  try { $h = & curl.exe -sS -I --max-time $TimeoutSec $Url 2>$null; return $h } catch { return $null }
}
function Test-Endpoint {
  param([string]$Path,[ValidateSet("GET","HEAD")] [string]$Method="GET")
  $url = ($BaseUrl.TrimEnd("/") + $Path)
  if($Method -eq "HEAD"){
    $h = Curl-Head $url
    if(!$h){ return @{ ok=$false; code=$null; url=$url; raw=$null } }
    $m = [regex]::Match($h, 'HTTP/\d\.\d\s+(?<c>\d{3})')
    $code = if($m.Success){ [int]$m.Groups["c"].Value } else { $null }
    return @{ ok=($code -ge 200 -and $code -lt 500); code=$code; url=$url; raw=$h }
  } else {
    $b = Curl-Json $url
    if(!$b){ return @{ ok=$false; code=$null; url=$url; raw=$null } }
    $h = Curl-Head $url
    $m = if($h){ [regex]::Match($h, 'HTTP/\d\.\d\s+(?<c>\d{3})') } else { $null }
    $code = if($m -and $m.Success){ [int]$m.Groups["c"].Value } else { 200 }
    return @{ ok=($code -ge 200 -and $code -lt 400); code=$code; url=$url; raw=$b }
  }
}

function Grep-Routes {
  param([string]$Root)
  $routes = New-Object System.Collections.Generic.HashSet[string]
  if(!(Test-Path $Root)){ return @() }

  $files = Get-ChildItem -LiteralPath $Root -Recurse -File -Include *.cpp,*.hpp,*.h,*.cxx,*.cc -EA SilentlyContinue
  foreach($f in $files){
    try{
      $txt = Get-Content -LiteralPath $f.FullName -Raw -EA SilentlyContinue
      if(!$txt){ continue }
      $ms = [regex]::Matches($txt, '"/api/[a-zA-Z0-9_/\-]+' )
      foreach($m in $ms){
        $r = $m.Value.Trim('"')
        [void]$routes.Add($r)
      }
    } catch {}
  }

  # FIX: HashSet -> enumerate into array
  return @($routes) | Sort-Object
}

function Grep-Ops {
  param([string]$Root)
  $hits = @()
  if(!(Test-Path $Root)){ return @() }
  $files = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.ps1 -EA SilentlyContinue
  foreach($f in $files){
    try{
      $txt = Get-Content -LiteralPath $f.FullName -Raw -EA SilentlyContinue
      if(!$txt){ continue }
      if($txt -match '(?i)\b(agent|loop|codegen|compile|run|patch|apply_codegen|vibe|monaco|pnpm|next)\b'){
        $hits += $f.FullName
      }
    } catch {}
  }
  return $hits | Sort-Object -Unique
}

Ensure-Dir $Runtime

Say "`n=== NIFDU Agent-3 AUDIT (Completed vs Pending) ===`n" Yellow
Say ("Repo:    " + $Repo) DarkGray
Say ("BaseUrl: " + $BaseUrl) DarkGray
Say "[DBG] probes begin" Cyan

$probe = @(
  @{ name="Health";               path="/api/health" },
  @{ name="Ping";                 path="/api/ping" },
  @{ name="List";                 path="/api/list" },
  @{ name="Log";                  path="/api/log" },
  @{ name="Truth";                path="/api/truth" },

  @{ name="Chat";                 path="/api/chat" },
  @{ name="Codegen";              path="/api/codegen" },
  @{ name="Compile";              path="/api/compile" },
  @{ name="Run";                  path="/api/run" },

  @{ name="Agent Loop";           path="/api/agent/loop" },
  @{ name="Agent Meta";           path="/api/agent/meta" },

  @{ name="RAG";                  path="/api/rag" },
  @{ name="Train";                path="/api/train" },

  @{ name="AV Render";            path="/api/av/render" },
  @{ name="AV Sprite";            path="/api/av/sprite" },
  @{ name="AV Control";           path="/api/av/control" },

  @{ name="AV Status";            path="/api/av/status?job_id=test" },
  @{ name="AV Latest";            path="/api/av/latest" },
  @{ name="AV List";              path="/api/av/list?limit=5" },

  @{ name="Serve media generated"; path="/media/generated/"; head=$true }
)

$live = @()
foreach($p in $probe){
  Say ("[DBG] probing: " + $p.name + " -> " + $p.path) DarkCyan
  $isHead = ($p.ContainsKey("head") -and $p.head -eq $true)
  $r = Test-Endpoint -Path $p.path -Method ($(if($isHead){"HEAD"}else{"GET"}))
  $live += [pscustomobject]@{ name=$p.name; path=$p.path; ok=$r.ok; code=$r.code; url=$r.url }
}

Say "[DBG] probes end" Cyan
Say "[DBG] Grep-Routes begin" Cyan
$routes  = Grep-Routes -Root (Join-Path $SrcRoot "http")
Say ("[DBG] Grep-Routes end count=" + $routes.Count) Cyan
Say "[DBG] Grep-Ops begin" Cyan
$opsHits = Grep-Ops -Root $OpsRoot
Say ("[DBG] Grep-Ops end count=" + $opsHits.Count) Cyan

$vibeCandidates = @(
  "C:\webroot\sophyane.com\www\apps\vibe",
  "C:\webroot\sophyane.com\www\apps\vibe_studio_live",
  "C:\nifdu\src\apps\sophyane_live",
  "C:\nifdu\src\apps\vibe_studio_live"
)
$vibeFound = @()
foreach($c in $vibeCandidates){ if(Test-Path $c){ $vibeFound += $c } }

function Mark($id,$title,$complete,$evidence){
  [pscustomobject]@{ id=$id; title=$title; status=($(if($complete){"COMPLETED"}else{"PENDING"})); evidence=$evidence }
}

$L = @()
$liveMap = @{}
foreach($x in $live){ $liveMap[$x.path] = $x }

$L += Mark "A1" "API server alive (health/ping)" (($liveMap["/api/health"].ok -or $liveMap["/api/ping"].ok)) ("health=" + $liveMap["/api/health"].code + " ping=" + $liveMap["/api/ping"].code)
$L += Mark "A2" "Project listing / discovery API" ($liveMap["/api/list"].ok) ("code=" + $liveMap["/api/list"].code)
$L += Mark "A3" "Chat instruction endpoint (/api/chat)" ($liveMap["/api/chat"].ok) ("code=" + $liveMap["/api/chat"].code)
$L += Mark "A4" "Code generation endpoint (/api/codegen)" ($liveMap["/api/codegen"].ok) ("code=" + $liveMap["/api/codegen"].code)
$L += Mark "A5" "Compile endpoint (/api/compile)" ($liveMap["/api/compile"].ok) ("code=" + $liveMap["/api/compile"].code)
$L += Mark "A6" "Run endpoint (/api/run)" ($liveMap["/api/run"].ok) ("code=" + $liveMap["/api/run"].code)
$L += Mark "A7" "Agent Loop endpoint (/api/agent/loop) (true autonomy)" ($liveMap["/api/agent/loop"].ok) ("code=" + $liveMap["/api/agent/loop"].code)
$L += Mark "A8" "Agent meta/capabilities endpoint (/api/agent/meta)" ($liveMap["/api/agent/meta"].ok) ("code=" + $liveMap["/api/agent/meta"].code)
$L += Mark "A9" "Vibe Coding UI exists (chat + code + preview)" ($vibeFound.Count -gt 0) ($(if($vibeFound.Count -gt 0){ $vibeFound -join "; " } else { "not found in common locations" }))
$L += Mark "A10" "File ops authority (apply patches / edit files via ops scripts)" ($opsHits.Count -gt 0) ("ops_hits=" + $opsHits.Count)
$L += Mark "A11" "RAG endpoint (/api/rag) (memory/RAG)" ($liveMap["/api/rag"].ok) ("code=" + $liveMap["/api/rag"].code)
$L += Mark "A12" "Training endpoint (/api/train)" ($liveMap["/api/train"].ok) ("code=" + $liveMap["/api/train"].code)

$L += Mark "A13" "AV render endpoints (render/sprite/control)" (($liveMap["/api/av/render"].ok) -or ($liveMap["/api/av/sprite"].ok) -or ($liveMap["/api/av/control"].ok)) ("render=" + $liveMap["/api/av/render"].code + " sprite=" + $liveMap["/api/av/sprite"].code + " control=" + $liveMap["/api/av/control"].code)
$L += Mark "A14" "AV job status APIs (status/latest/list)" (($liveMap["/api/av/latest"].ok) -or ($liveMap["/api/av/list?limit=5"].ok) -or ($liveMap["/api/av/status?job_id=test"].ok)) ("status=" + $liveMap["/api/av/status?job_id=test"].code + " latest=" + $liveMap["/api/av/latest"].code + " list=" + $liveMap["/api/av/list?limit=5"].code)
$L += Mark "A15" "Serve generated media via NIFDU (/media/generated/*)" ($liveMap["/media/generated/"].ok) ("head_code=" + $liveMap["/media/generated/"].code)

$L += Mark "R1" "Workspace FS API (list/read/write/delete) exposed over HTTP" ($routes -contains "/api/fs/list" -or $routes -contains "/api/fs/read" -or $routes -contains "/api/fs/write") ("routes_found=" + ((@("/api/fs/list","/api/fs/read","/api/fs/write","/api/fs/delete") | ? { $routes -contains $_ }) -join ","))
$L += Mark "R2" "Terminal/PTY streaming (interactive)" ($routes -contains "/api/pty" -or $routes -contains "/api/term" -or $routes -contains "/api/shell") ("hint_routes=" + ((@("/api/pty","/api/term","/api/shell") | ? { $routes -contains $_ }) -join ","))
$L += Mark "R3" "Realtime logs/stream channel (SSE/WebSocket) for agent loop" ($routes -contains "/api/stream" -or $routes -contains "/socket" -or $routes -contains "/api/run/poll") ("hint_routes=" + ((@("/api/stream","/socket","/api/run/poll") | ? { $routes -contains $_ }) -join ","))
$L += Mark "R4" "Project scaffolding templates (create project, init, dependencies)" ($routes -contains "/api/project" -or $routes -contains "/api/projects/accept") ("hint_routes=" + ((@("/api/project","/api/projects/accept") | ? { $routes -contains $_ }) -join ","))
$L += Mark "R5" "Secrets management (.env integration) via API (read-only + inject)" ($routes -contains "/api/env" -or $routes -contains "/api/secrets") ("hint_routes=" + ((@("/api/env","/api/secrets") | ? { $routes -contains $_ }) -join ","))

$completed = $L | ? { $_.status -eq "COMPLETED" }
$pending   = $L | ? { $_.status -eq "PENDING" }

$report = [pscustomobject]@{
  timestamp = (Get-Date).ToString("s")
  base_url  = $BaseUrl
  live_endpoints = $live
  discovered_routes_count = $routes.Count
  discovered_routes_sample = ($routes | Select-Object -First 80)
  ops_scripts_count = $opsHits.Count
  ops_scripts_sample = ($opsHits | Select-Object -First 50)
  vibe_paths_found = $vibeFound
  checklist = $L
  summary = @{
    completed = $completed.Count
    pending   = $pending.Count
    completed_ids = ($completed.id)
    pending_ids   = ($pending.id)
  }
}

Ensure-Dir $Runtime
$jsonPath = Join-Path $Runtime "agent3_audit_latest.json"
$txtPath  = Join-Path $Runtime "agent3_audit_latest.txt"

($report | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("NIFDU Agent-3 Audit @ " + $report.timestamp)
$lines.Add("Base: " + $BaseUrl)
$lines.Add("")
$lines.Add("COMPLETED (" + $completed.Count + "):")
foreach($c in $completed){ $lines.Add("  [" + $c.id + "] " + $c.title + "  :: " + $c.evidence) }
$lines.Add("")
$lines.Add("PENDING (" + $pending.Count + "):")
foreach($p in $pending){ $lines.Add("  [" + $p.id + "] " + $p.title + "  :: " + $p.evidence) }
$lines.Add("")
$lines.Add("Discovered routes: " + $routes.Count)
$lines.Add("Ops scripts: " + $opsHits.Count)
$lines | Set-Content -LiteralPath $txtPath -Encoding UTF8

Say "`n=== RESULT ===" Yellow
Say ("Completed: " + $completed.Count) Green
Say ("Pending:   " + $pending.Count) DarkYellow
Say ("Report JSON: " + $jsonPath) Cyan
Say ("Report TXT : " + $txtPath) Cyan

Say "`nTop Pending (what usually blocks Replit parity):" Yellow
($pending | Select-Object -First 8) | % { Say (" - [" + $_.id + "] " + $_.title) DarkYellow }