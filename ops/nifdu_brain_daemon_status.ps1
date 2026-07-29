param([string]$Runtime = "C:\nifdu\runtime\brain")
$ErrorActionPreference="Continue"

$Signals = Join-Path $Runtime "signals"
$HbFile  = Join-Path $Signals "heartbeat.json"
$PidFile = Join-Path $Signals "daemon.pid"
$StopFile= Join-Path $Signals "STOP"

Write-Host "
=== NIFDU BRAIN DAEMON STATUS ===
"

$stopPresent = Test-Path $StopFile

$pidVal = "(missing)"
if(Test-Path $PidFile){
  try{ $pidVal = (Get-Content $PidFile -EA SilentlyContinue | Select-Object -First 1) }catch{}
}

$hbVal = "(missing)"
if(Test-Path $HbFile){
  try{ $hbVal = (Get-Content $HbFile -Raw -EA SilentlyContinue) }catch{}
}

Write-Host ("STOP present: " + $stopPresent)
Write-Host ("PID file    : " + $pidVal)
Write-Host ("Heartbeat   : " + $hbVal)

Write-Host ""
Write-Host "Tail log:"

$Logs = Join-Path $Runtime "logs"
$lf = Get-ChildItem $Logs -Filter "daemon_*.log" -File -EA SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1

if($lf){
  try{ Get-Content $lf.FullName -Tail 40 -EA SilentlyContinue }catch{}
} else {
  Write-Host "(no log file yet)"
}
