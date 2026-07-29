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
param(
  [string]$ProjectRoot = "",
  [string]$Prompt      = "",
  [string]$ProjectName = "",
  [string]$BrainUrl    = "http://127.0.0.1:8000/api/codegen",
  [string]$EnvFile     = "C:\ENV\.env",

  # Run command strategy
  [ValidateSet("next","cmake","custom")]
  [string]$Mode        = "next",
  [string]$CustomCmd   = "",

  # Typical node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev ports to supervise
  [int[]]$UiPorts      = @(3000,3001),
  [int]$PreferredUiPort= 3001,

  # Smoke tests (optional)
  [string]$Domain      = "sophyane.com",
  [ValidateSet("local","dns","off")]
  [string]$TestMode    = "local",
  [string[]]$SmokeUrls = @(
    "https://sophyane.com/api/health",
    "https://sophyane.com/apps/vibe/preview/"
  ),

  [int]$MaxIters       = 12
)

$ErrorActionPreference="Stop"
. "$PSScriptRoot\lib\agent3_lib.ps1"

if([string]::IsNullOrWhiteSpace($ProjectRoot)){ throw "Provide -ProjectRoot" }
if([string]::IsNullOrWhiteSpace($Prompt)){ throw "Provide -Prompt" }
if(!(Test-Path $ProjectRoot)){ throw "Missing ProjectRoot: $ProjectRoot" }
if([string]::IsNullOrWhiteSpace($ProjectName)){ $ProjectName = Split-Path $ProjectRoot -Leaf }

# --- deterministic folders ---
$metaDir   = Join-Path $ProjectRoot ".nifdu"
$statePath = Join-Path $metaDir "agent3_state.json"
$runDir    = Join-Path $metaDir "runs"
$backupDir = Join-Path $metaDir "backups"
A3-EnsureDir $metaDir
A3-EnsureDir $runDir
A3-EnsureDir $backupDir

# --- env + redaction ---
$envMap = A3-ReadEnvFile $EnvFile

# --- init state ---
$rid     = "{0}_{1}" -f $ProjectName,(Get-Date -Format "yyyyMMdd_HHmmss")
$runLog  = Join-Path $runDir "$rid.jsonl"
$runHtml = Join-Path $runDir "$rid.html"

$state = A3-LoadState $statePath
if(-not $state){
  $state = [pscustomobject]@{
    project = [pscustomobject]@{
      name = $ProjectName
      root = $ProjectRoot
      stack = $Mode
      selected = [pscustomobject]@{ uiPort=$PreferredUiPort }
    }
    run = [pscustomobject]@{
      id = $rid
      started = A3-NowIso
      status = "running"
      iter = 0
    }
    history = @()
    last_success = $null
  }
} else {
  $state.run = [pscustomobject]@{ id=$rid; started=A3-NowIso; status="running"; iter=0 }
}

function LogStep([string]$kind,[string]$msg,[hashtable]$extra=@{}){
  $obj = [ordered]@{
    t = A3-NowIso
    kind = $kind
    msg = (A3-Redact $msg $envMap)
    extra = $extra
  }
  Add-Content -Path $runLog -Value (A3-Json $obj 30) -Encoding UTF8
}

LogStep "start" "Agent3 run started" @{ runId=$rid; project=$ProjectRoot; mode=$Mode; brain=$BrainUrl }

function Ensure-UiPort([int]$port){
  $own = A3-GetPortOwner $port
  if($own){
    $nm = ""
    try { $nm = [string]$own.name } catch { $nm = "" }

    $okOwner = $false
    if($nm){
      $l = $nm.ToLowerInvariant()
      if($l -match "node|pnpm|npm|next"){ $okOwner = $true }
    }

    if($okOwner){
      LogStep "port" ("Port {0} used by PID {1} ({2}) - accepting." -f $port,$own.pid,$own.name) @{ port=$port; pid=$own.pid; name=$own.name }
      return $true
    } else {
      LogStep "port" ("Port {0} used by PID {1} ({2}) - killing." -f $port,$own.pid,$own.name) @{ port=$port; pid=$own.pid; name=$own.name }
      A3-KillPid $own.pid
      Start-Sleep -Milliseconds 400
      return $false
    }
  }
  return $false
}

function Start-DevIfNeeded(){
  $picked = $null

  foreach($p in $UiPorts){
    if(Ensure-UiPort $p){ $picked = $p; break }
  }

  if(-not $picked){
    $picked = $PreferredUiPort

    $cmd = ""
    if($Mode -eq "next"){
      # IMPORTANT: forward args to next via pnpm
      $cmd = "node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev -- -p $picked"
    } elseif($Mode -eq "cmake"){
      $cmd = "cmake --build . --config Release"
    } else {
      if([string]::IsNullOrWhiteSpace($CustomCmd)){ throw "Mode=custom requires -CustomCmd" }
      $cmd = $CustomCmd
    }

    $pol = A3-PolicyCheckCommand $cmd
    if(-not $pol.ok){ throw $pol.reason }

    LogStep "start_cmd" $cmd @{ cwd=$ProjectRoot }
    Start-Process -FilePath "cmd.exe" -ArgumentList @("/c",$cmd) -WorkingDirectory $ProjectRoot -WindowStyle Hidden | Out-Null
    Start-Sleep -Milliseconds 800

    $ok=$false
    for($i=0;$i -lt 30;$i++){
      if(Ensure-UiPort $picked){ $ok=$true; break }
      Start-Sleep -Milliseconds 300
    }
    if(-not $ok){ LogStep "warn" "UI did not bind quickly; continuing anyway." @{ port=$picked } }
  }

  $state.project.selected.uiPort = $picked
  return $picked
}

$uiPort = Start-DevIfNeeded
LogStep "ui" ("UI port selected: {0}" -f $uiPort) @{ uiPort=$uiPort }

for($iter=1; $iter -le $MaxIters; $iter++){
  $state.run.iter = $iter
  A3-SaveState $statePath $state

  LogStep "iter" ("Iteration {0}/{1}" -f $iter,$MaxIters) @{}

  $probe = A3-RunCmd ("curl.exe -sS -i --max-time 6 http://127.0.0.1:{0}/" -f $uiPort) $ProjectRoot 60
  $probeText = ($probe.out + "`n" + $probe.err).Trim()
  $errInfo = A3-ClassifyError $probeText

  $ctx = [ordered]@{
    project = [ordered]@{
      name = $ProjectName
      root = $ProjectRoot
      mode = $Mode
      uiPort = $uiPort
    }
    prompt = $Prompt
    iteration = $iter
    observed = [ordered]@{
      probe_exit = $probe.exit
      probe_kind = $errInfo.kind
      probe_summary = $errInfo.summary
      probe_hot = $errInfo.hot
      fingerprint = $errInfo.fingerprint
    }
    policy = [ordered]@{
      constraints = @(
        "Only modify files inside project root",
        "Prefer minimal diffs/edits",
        "Return JSON with files[] or edits[] or patches[]",
        "Do not include secrets",
        "After patch, include verification hints"
      )
    }
  }

  $body = A3-Json $ctx 30
  LogStep "brain_req" "POST /api/codegen" @{ bytes=$body.Length; fingerprint=$errInfo.fingerprint }

  $resp = $null
  try{
    $resp = Invoke-RestMethod -Uri $BrainUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $body -TimeoutSec 120
  } catch {
    LogStep "brain_err" ("Brain call failed: " + $_.Exception.Message) @{}
    throw
  }

  LogStep "brain_ok" "Brain response received" @{}

  $iterBackupDir = Join-Path $backupDir ("iter_{0}_{1}" -f $iter,(Get-Date -Format "yyyyMMdd_HHmmss"))
  A3-EnsureDir $iterBackupDir
  $changes=@()

  if($resp.files){   $changes += (A3-WriteFiles $ProjectRoot $resp.files $iterBackupDir) }
  if($resp.edits){   $changes += (A3-ApplyEdits $ProjectRoot $resp.edits $iterBackupDir) }
  if($resp.patches){ $changes += (A3-ApplyUnifiedDiffBasic $ProjectRoot $resp.patches $iterBackupDir) }

  if($changes.Count -eq 0){
    LogStep "warn" "Brain returned no applicable changes (files/edits/patches empty). Stopping." @{}
    $state.run.status = "no_changes"
    break
  }

  LogStep "apply" "Changes applied" @{ count=$changes.Count; backupDir=$iterBackupDir }
  $state.history += [pscustomobject]@{
    iter = $iter
    t = A3-NowIso
    fingerprint = $errInfo.fingerprint
    changes = $changes
  }
  A3-SaveState $statePath $state

  if($TestMode -ne "off"){
    $resolve = ""
    if($TestMode -eq "local"){ $resolve = "--resolve $Domain`:443:127.0.0.1" }
    foreach($u in $SmokeUrls){
      $h = A3-SmokeCurl $u $resolve
      LogStep "smoke" ("HEAD " + $u) @{ head=$h }
    }
  }

  $code = (cmd.exe /c ("curl.exe -sS -o NUL -w ""%{http_code}"" --max-time 6 http://127.0.0.1:{0}/" -f $uiPort) | Out-String).Trim()
  if($code -match "^(200|301|302|307|308)$"){
    $state.last_success = [pscustomobject]@{ iter=$iter; t=A3-NowIso; uiPort=$uiPort }
    $state.run.status = "success"
    A3-SaveState $statePath $state
    LogStep "success" ("UI is healthy (http code {0})" -f $code) @{ code=$code }
    break
  } else {
    LogStep "loop" ("UI not healthy (http code {0}); continuing." -f $code) @{ code=$code }
  }
}

if($state.run.status -eq "running"){ $state.run.status = "done" }
A3-SaveState $statePath $state
A3-WriteHtmlReport $runHtml $state

A3-Say ""
A3-Say "DONE." Green
A3-Say ("State:  " + $statePath) DarkGray
A3-Say ("Log:    " + $runLog) DarkGray
A3-Say ("Report: " + $runHtml) DarkGray