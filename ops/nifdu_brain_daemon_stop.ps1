param([string]$Runtime = "C:\nifdu\runtime\brain")
$ErrorActionPreference="Stop"
$Signals = Join-Path $Runtime "signals"
New-Item -ItemType Directory -Force -Path $Signals | Out-Null
$StopFile = Join-Path $Signals "STOP"
Set-Content -LiteralPath $StopFile -Encoding UTF8 -Value "stop"
Write-Host "STOP written: $StopFile"
