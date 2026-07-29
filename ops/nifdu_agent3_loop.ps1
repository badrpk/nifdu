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

  [Parameter(Mandatory=$true,
  [Alias("Prompt","prompt","UserPrompt","Goal","goal","Text","text")


# A3_PNPM_NO_PROMPT_V1
# Make pnpm non-interactive for module purge confirmations (covers indirect invocations too)
try { $env:CI = "true" } catch {}
try { $env:PNPM_CONFIG_CONFIRM_MODULES_PURGE = "false" } catch {}
# END A3_PNPM_NO_PROMPT_V1
# A3_CI_ENV_V1
try { $env:CI = "true" } catch {}
# END A3_CI_ENV_V1
# A3_PROMPT_ARGS_FALLBACK_V1
# If caller passes free-form trailing args (or if -Prompt was not recognized earlier),
# treat them as the prompt text.
try{
  if((-not $Prompt) -and $args -and $args.Count -gt 0){
    $Prompt = ($args -join " ")
  }
}catch{}
# END A3_PROMPT_ARGS_FALLBACK_V1
]
  [string]$Prompt = ""
)
][string]$SessionId,
  [Parameter(Mandatory=$true)][string]$Project,
  [Parameter(Mandatory=$true)][string]$Prompt
)

$ErrorActionPreference="SilentlyContinue"
$logDir = "C:\nifdu\runtime"
try{ New-Item -ItemType Directory -Force -Path $logDir | Out-Null }catch{}
$elog = Join-Path $logDir ("agent_events_" + $SessionId + ".log")

function Emit([string]$s){
  try { Add-Content -LiteralPath $elog -Value $s -Encoding utf8 } catch {}
}

Emit "[AGENT3] loop start"
Emit ("session_id=" + $SessionId)
Emit ("project=" + $Project)
Emit ("prompt=" + $Prompt)

# Decide a reasonable workdir for node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev
$workdir = ""
try {
  $cand = "C:\nifdu\src\apps\$Project"
  if(Test-Path $cand){ $workdir = ($cand -replace '\\','/') }
} catch {}
if([string]::IsNullOrWhiteSpace($workdir)){
  $workdir = "C:/nifdu"
}
Emit ("workdir=" + $workdir)

# 1) CODEGEN
Emit "[1/3] codegen"
try{
  $j = @{ project=$Project; prompt=$Prompt; session_id=$SessionId; brain="auto"; mode="vibe_coding" } | ConvertTo-Json -Depth 10
  $res = curl.exe -s -X POST http://127.0.0.1/api/codegen -H "Content-Type: application/json" --data $j
  Emit ("[CODEGEN-RES] " + $res)
} catch {
  Emit "[ERROR] codegen failed"
}

Start-Sleep -Milliseconds 250

# 2) RUN (node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev)
Emit "[2/3] run/start node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev"
try{
  $runBody = @{
    command = "node node_modules\next\dist\bin\node node_modules\next\dist\bin\node node_modules\next\dist\bin\next dev     workdir = $workdir
    capture = $true
  } | ConvertTo-Json -Depth 6

  $runRes = curl.exe -s -X POST http://127.0.0.1/api/run/start -H "Content-Type: application/json" --data $runBody
  Emit ("[RUN-START] " + $runRes)

  # If server returned a new run session_id, prefer it for polling logs
  $pollSid = $SessionId
  try {
    $jr = $runRes | ConvertFrom-Json
    if($jr.session_id){ $pollSid = [string]$jr.session_id }
  } catch {}

  Emit ("poll_session_id=" + $pollSid)

  # 3) Poll logs a few times
  Emit "[3/3] run/poll (stream)"
  for($i=0; $i -lt 12; $i++){
    $p = curl.exe -s ("http://127.0.0.1/api/run/poll?session_id=" + $pollSid)
    if($p){ Emit ("[POLL " + $i + "] " + $p) }
    Start-Sleep -Milliseconds 750
  }

} catch {
  Emit "[ERROR] run/start or poll failed"
}

Emit "[DONE] loop finished (UI should keep polling /api/agent/events)"