param(
  [string]$App = "C:\nifdu\src\apps\sophyane_live",
  [int]$Port = 3000,
  [int]$CheckEveryMs = 2000,
  [switch]$AutoRestart
)

$ErrorActionPreference="Continue"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

$OpsRoot = Split-Path -Parent $PSCommandPath
$Free = Join-Path $OpsRoot "free_port.ps1"

if(!(Test-Path $Free)){ throw ("Missing: " + $Free) }
if(!(Test-Path $App)){ throw ("Missing: " + $App) }

Say "
=== NIFDU UI PORT GOVERNOR ===" Yellow
Say ("App: " + $App) DarkGray
Say ("Port: " + $Port) DarkGray
Say ("AutoRestart: " + [bool]$AutoRestart) DarkGray
Say ("CheckEveryMs: " + $CheckEveryMs) DarkGray
Say ("FreePortScript: " + $Free) DarkGray
Say ("AllowProcess: node") DarkGray
Say "" Gray

function Get-ListeningPids([int]$p){
  try{
    $lines = @(cmd.exe /c ("netstat -ano | findstr LISTENING | findstr :" + $p))
    if(-not $lines -or $lines.Count -eq 0){ return @() }

    $pids = @()
    foreach($l in $lines){
      $pidX = ($l -split '\s+')[-1]
      if($pidX -match '^\d+$'){ $pids += [int]$pidX }
    }
    return ($pids | Sort-Object -Unique)
  } catch { return @() }
}

function Start-NextDev([string]$appDir,[int]$p){
  try{
    Say ("Starting Next dev on port " + $p + "...") Cyan
    $env:PORT = "$p"
    Start-Process -FilePath "node" -WorkingDirectory $appDir -ArgumentList @(
      "node_modules\next\dist\bin\next",
      "dev"
    ) | Out-Null
  } catch {
    Say ("Start-NextDev failed: " + $_.Exception.Message) DarkYellow
  }
}

while($true){
  try{
    $pids = Get-ListeningPids $Port

    if($pids -and $pids.Count -gt 0){
      # Something is listening. If it's node, we treat it as allowed and do nothing.
      $allAllowed = $true
      foreach($pidX in $pids){
        $pname = ""
        try { $pname = (Get-Process -Id $pidX -EA Stop).ProcessName } catch { $pname = "" }
        if($pname -and ($pname -ieq "node")){
          # allowed
        } else {
          $allAllowed = $false
        }
      }

      if(-not $allAllowed){
        Say ("Port " + $Port + " held by non-allowed process -> freeing...") Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Free" -Port $Port -AllowProcess node | Out-Host
      } else {
        # Port held by node => OK
        # Say ("Port " + $Port + " is owned by node (OK)") DarkGray
      }

    } else {
      # Nothing listening
      if($AutoRestart){
        Start-NextDev $App $Port
        Start-Sleep -Milliseconds 400
      }
    }

  } catch {
    Say ("Governor error: " + $_.Exception.Message) DarkYellow
  }

  Start-Sleep -Milliseconds $CheckEveryMs
}