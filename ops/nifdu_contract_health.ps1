param(
  [string]$Contract = "C:\nifdu\ops\contracts\build_run_preview_contract.json",
  [int]$TimeoutSec = 6
)

$ErrorActionPreference="Continue"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

if(!(Test-Path $Contract)){ throw "Missing contract: $Contract" }
$cfg = Get-Content $Contract -Raw -Encoding UTF8 | ConvertFrom-Json

Say "
=== CONTRACT HEALTH ===" Yellow
Say ("Domain: " + $cfg.domain) DarkGray
Say ("UI: :" + $cfg.ui.port) DarkGray
Say ("API: :" + $cfg.api.port) DarkGray
Say ("Preview: " + $cfg.preview.path + " -> " + $cfg.preview.upstream) DarkGray
Say "" Gray

# Ports listening
$uiListen  = @(cmd.exe /c ("netstat -ano | findstr LISTENING | findstr :" + $cfg.ui.port))
$apiListen = @(cmd.exe /c ("netstat -ano | findstr LISTENING | findstr :" + $cfg.api.port))

if($uiListen -and $uiListen.Count -gt 0){ Say ("LISTEN OK UI :" + $cfg.ui.port) Green; $uiListen | Out-Host } else { Say ("LISTEN FAIL UI :" + $cfg.ui.port) Red }
if($apiListen -and $apiListen.Count -gt 0){ Say ("LISTEN OK API :" + $cfg.api.port) Green; $apiListen | Out-Host } else { Say ("LISTEN FAIL API :" + $cfg.api.port) Red }

# UI HTTP probe
try{
  cmd.exe /c ("curl.exe -sS --max-time " + $TimeoutSec + " http://127.0.0.1:" + $cfg.ui.port + "/ >NUL")
  if($LASTEXITCODE -eq 0){ Say ("UI OK http://127.0.0.1:" + $cfg.ui.port + "/") Green } else { Say ("UI FAIL curl exit " + $LASTEXITCODE) Red }
} catch { Say ("UI FAIL " + $_.Exception.Message) Red }

# Preview path via domain (TLS)
try{
  $hdr = cmd.exe /c ("curl.exe -k -sS --max-time " + $TimeoutSec + " -I https://" + $cfg.domain + $cfg.preview.path)
  if($LASTEXITCODE -eq 0){
    Say ("TLS OK https://" + $cfg.domain + $cfg.preview.path) Green
    $hdr | Out-Host
  } else {
    Say ("TLS FAIL https://" + $cfg.domain + $cfg.preview.path + " (exit " + $LASTEXITCODE + ")") DarkYellow
    $hdr | Out-Host
  }
} catch { Say ("TLS WARN " + $_.Exception.Message) DarkYellow }