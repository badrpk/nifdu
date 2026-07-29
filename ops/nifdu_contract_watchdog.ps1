param(
  [string]$Contract = "C:\nifdu\ops\contracts\build_run_preview_contract.json"
)

$ErrorActionPreference="Continue"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

if(!(Test-Path $Contract)){ throw "Missing contract: $Contract" }
$cfg = Get-Content $Contract -Raw -Encoding UTF8 | ConvertFrom-Json

$opsRoot = Split-Path -Parent $PSCommandPath
$free = Join-Path $opsRoot "free_port.ps1"
$start = Join-Path $opsRoot "nifdu_contract_start.ps1"
$proxy = Join-Path $opsRoot "nifdu_contract_proxy_apply.ps1"

function IsListening([int]$p){
  try{
    $lines = @(cmd.exe /c ("netstat -ano | findstr LISTENING | findstr :" + $p))
    return ($lines -and $lines.Count -gt 0)
  } catch { return $false }
}

Say "
=== CONTRACT WATCHDOG (AUTOHEAL) ===" Yellow
Say ("Contract: " + $Contract) DarkGray
Say ("EveryMs: " + $cfg.watchdog.everyMs) DarkGray
Say "" Gray

# Apply proxy once at start
if(Test-Path $proxy){
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $proxy -Contract $Contract | Out-Host
}

while($true){
  try{
    $uiOk  = IsListening $cfg.ui.port
    $apiOk = IsListening $cfg.api.port

    if(-not $uiOk){
      Say ("UI down on :" + $cfg.ui.port + " -> restarting...") DarkYellow
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start -Contract $Contract -NoWatch | Out-Host
    }

    if(-not $apiOk){
      Say ("API down on :" + $cfg.api.port + " -> restarting...") DarkYellow
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start -Contract $Contract -NoWatch | Out-Host
    }
  } catch {
    Say ("Watchdog error: " + $_.Exception.Message) DarkYellow
  }

  Start-Sleep -Milliseconds ([int]$cfg.watchdog.everyMs)
}