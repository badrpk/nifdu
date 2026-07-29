param(
  [string]$Daemon = "C:\nifdu\ops\nifdu_brain_daemon.ps1",
  [string]$WorkerPath = "C:\nifdu\ops\nifdu_brain_worker.ps1",
  [string]$EnvFile = "C:\ENV\.env",
  [string]$Runtime = "C:\nifdu\runtime\brain",
  [int]$IntervalSec = 3,
  [int]$JitterMsMax = 250,
  [int]$WorkerTimeout = 120,
  [string]$DefaultTenant = "nifdu.com",
  [string]$DefaultUser = "local",
  [string]$DefaultProject = "global",
  [string]$OllamaUrl = "http://127.0.0.1:11434",
  [string]$OllamaModel = "nomic-embed-text",
  [string]$OpenAIBase = "https://api.openai.com/v1",
  [string]$OpenAIModel = "text-embedding-3-small"
)

$ErrorActionPreference="Stop"
if(!(Test-Path $Daemon)){ throw "Missing daemon: $Daemon" }

$Signals = Join-Path $Runtime "signals"
New-Item -ItemType Directory -Force -Path $Signals | Out-Null
$StopFile = Join-Path $Signals "STOP"
if(Test-Path $StopFile){ Remove-Item -Force $StopFile -EA SilentlyContinue }

Start-Process -FilePath "powershell.exe" -ArgumentList @(
  "-NoProfile","-ExecutionPolicy","Bypass",
  "-File",$Daemon,
  "-WorkerPath",$WorkerPath,
  "-EnvFile",$EnvFile,
  "-Runtime",$Runtime,
  "-IntervalSec",$IntervalSec,
  "-JitterMsMax",$JitterMsMax,
  "-WorkerTimeout",$WorkerTimeout,
  "-DefaultTenant",$DefaultTenant,
  "-DefaultUser",$DefaultUser,
  "-DefaultProject",$DefaultProject,
  "-OllamaUrl",$OllamaUrl,
  "-OllamaModel",$OllamaModel,
  "-OpenAIBase",$OpenAIBase,
  "-OpenAIModel",$OpenAIModel
) -WindowStyle Hidden | Out-Null

Write-Host "Started daemon (hidden). Runtime=$Runtime"
