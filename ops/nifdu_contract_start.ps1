param(
  [string]$Contract = "C:\nifdu\ops\contracts\build_run_preview_contract.json",
  [switch]$NoWatch
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

if(!(Test-Path $Contract)){ throw "Missing contract: $Contract" }
$cfg = Get-Content $Contract -Raw -Encoding UTF8 | ConvertFrom-Json

$opsRoot = Split-Path -Parent $PSCommandPath
$free = Join-Path $opsRoot "free_port.ps1"
if(!(Test-Path $free)){ throw "Missing: $free" }

# --- Helpers ---
function IsListening([int]$p){
  try{
    $lines = @(cmd.exe /c ("netstat -ano | findstr LISTENING | findstr :" + $p))
    return ($lines -and $lines.Count -gt 0)
  } catch { return $false }
}

function StartUi(){
  if(IsListening $cfg.ui.port){
    Say ("UI already listening on :" + $cfg.ui.port) Green
    return
  }

  # free port unless owned by node
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$free" -Port $cfg.ui.port -AllowProcess node | Out-Host

  if(IsListening $cfg.ui.port){
    Say ("UI is already listening after free (OK) :" + $cfg.ui.port) Green
    return
  }

  Say ("Starting UI (Next) on :" + $cfg.ui.port + "...") Cyan
  Push-Location $cfg.ui.appDir
  $env:PORT = "" + $cfg.ui.port
  Start-Process -FilePath "node" -WorkingDirectory $cfg.ui.appDir -ArgumentList @(
    "node_modules\next\dist\bin\next",
    "dev"
  ) | Out-Null
  Pop-Location
}

function StartApi(){
  if(IsListening $cfg.api.port){
    Say ("API already listening on :" + $cfg.api.port) Green
    return
  }

  # free port (allow nifdu if already holds it)
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$free" -Port $cfg.api.port -AllowProcess nifdu | Out-Host

  if(IsListening $cfg.api.port){
    Say ("API is already listening after free (OK) :" + $cfg.api.port) Green
    return
  }

  if(!(Test-Path $cfg.api.start.exe)){
    Say ("WARN: API exe missing: " + $cfg.api.start.exe) DarkYellow
    return
  }

  Say ("Starting API (nifdu) on :" + $cfg.api.port + "...") Cyan
  # If nifdu.exe takes a port arg later, add it into contract.json "api.start.args"
  Start-Process -FilePath $cfg.api.start.exe -WorkingDirectory (Split-Path -Parent $cfg.api.start.exe) -ArgumentList @() | Out-Null
}

Say "
=== CONTRACT START ===" Yellow
Say ("Contract: " + $Contract) DarkGray
StartUi
StartApi

if(-not $NoWatch){
  $watch = Join-Path $opsRoot "nifdu_contract_watchdog.ps1"
  if(Test-Path $watch){
    Say "Starting watchdog in background..." DarkGray
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
      "-NoProfile","-ExecutionPolicy","Bypass","-File",$watch,"-Contract",$Contract
    ) | Out-Null
  } else {
    Say "WARN: Watchdog script missing." DarkYellow
  }
}

Say "OK: contract start complete." Green