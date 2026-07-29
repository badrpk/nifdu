param(
  [string]$WorkerPath,
  [string]$EnvFile,
  [string]$Runtime,
  [int]$IntervalSec,
  [int]$JitterMsMax,
  [int]$WorkerTimeout,

  [string]$DefaultTenant,
  [string]$DefaultUser,
  [string]$DefaultProject,

  [string]$OllamaUrl,
  [string]$OllamaModel,

  [string]$OpenAIBase,
  [string]$OpenAIModel
)

$ErrorActionPreference="Continue"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }
function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Now(){ (Get-Date).ToString("o") }
function NowRid(){ (Get-Date -Format "yyyyMMdd_HHmmss_fff") }

# dirs
$Signals = Join-Path $Runtime "signals"
$Logs    = Join-Path $Runtime "logs"
$Tmp     = Join-Path $Runtime "tmp"
Ensure-Dir $Runtime; Ensure-Dir $Signals; Ensure-Dir $Logs; Ensure-Dir $Tmp

$StopFile  = Join-Path $Signals "STOP"
$HbFile    = Join-Path $Signals "heartbeat.json"
$LockFile  = Join-Path $Signals "daemon.lock"
$PidFile   = Join-Path $Signals "daemon.pid"
$LogFile   = Join-Path $Logs ("daemon_" + (Get-Date -Format "yyyyMMdd") + ".log")

# simple file logger
function LogLine($msg){
  try{
    ($(Now) + " " + $msg) | Add-Content -LiteralPath $LogFile -Encoding UTF8
  }catch{}
}

# mutex: exclusive open lock file
function Acquire-Lock(){
  try{
    $fs = [System.IO.File]::Open($LockFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
    return $fs
  }catch{
    return $null
  }
}

# write pid
try{
  Set-Content -LiteralPath $PidFile -Encoding UTF8 -Value ([string]$PID)
}catch{}

Say "
=== NIFDU BRAIN DAEMON (v1) ===
" Yellow
Say ("Runtime: " + $Runtime) DarkGray
Say ("Log: " + $LogFile) DarkGray
LogLine "[BOOT] pid=$PID"

while($true){
  if(Test-Path $StopFile){
    Say "STOP file detected => exiting daemon." Yellow
    LogLine "[STOP] stop file found"
    break
  }

  # lock
  $lock = Acquire-Lock
  if(-not $lock){
    LogLine "[SKIP] lock busy (another daemon/run active)"
    Start-Sleep -Milliseconds 400
    continue
  }

  try{
    # heartbeat
    try{
      @{ ok=$true; pid=$PID; ts=(Now); log=$LogFile } | ConvertTo-Json | Set-Content -LiteralPath $HbFile -Encoding UTF8
    }catch{}

    # jitter
    if($JitterMsMax -gt 0){
      Start-Sleep -Milliseconds (Get-Random -Minimum 0 -Maximum $JitterMsMax)
    }

    # run worker in a child powershell so we can time it out
    $args = @(
      "-NoProfile","-ExecutionPolicy","Bypass",
      "-File",$WorkerPath,
      "-EnvFile",$EnvFile,
      "-Runtime",$Runtime,
      "-DefaultTenant",$DefaultTenant,
      "-DefaultUser",$DefaultUser,
      "-DefaultProject",$DefaultProject,
      "-OllamaUrl",$OllamaUrl,
      "-OllamaModel",$OllamaModel,
      "-OpenAIBase",$OpenAIBase,
      "-OpenAIModel",$OpenAIModel
    )

    LogLine "[RUN] worker start"
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList $args -PassThru -WindowStyle Hidden

    if($WorkerTimeout -gt 0){
      if(-not $p.WaitForExit($WorkerTimeout * 1000)){
        try{ LogLine "[TIMEOUT] worker exceeded "$WorkerTimeouts" => kill pid=$($p.Id)"; Stop-Process -Id $p.Id -Force -EA SilentlyContinue }catch{}
      } else {
        LogLine "[DONE] worker exitcode=$($p.ExitCode)"
      }
    } else {
      $p.WaitForExit() | Out-Null
      LogLine "[DONE] worker exitcode=$($p.ExitCode)"
    }

  } catch {
    LogLine ("[ERR] " + $_)
  } finally {
    try{ $lock.Dispose() }catch{}
  }

  Start-Sleep -Seconds ([Math]::Max(1,$IntervalSec))
}

LogLine "[EXIT]"
