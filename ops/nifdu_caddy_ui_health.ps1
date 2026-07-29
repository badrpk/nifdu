param(
  [int]$UiPort = 3000,
  [string]$Domain = "sophyane.com",
  [int]$TimeoutSec = 6
)

$ErrorActionPreference="Continue"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

Say "
=== NIFDU CADDY/UI HEALTH CHECK ===" Yellow

# 0) Is UI port listening?
$listen = @(cmd.exe /c ("netstat -ano | findstr LISTENING | findstr :" + $UiPort))
if($listen -and $listen.Count -gt 0){
  Say ("LISTEN OK: :" + $UiPort) Green
  $listen | Out-Host
}else{
  Say ("LISTEN FAIL: :" + $UiPort + " (nothing listening)") Red
}

# 1) Local UI HTTP check
try{
  cmd.exe /c ("curl.exe -sS --max-time " + $TimeoutSec + " http://127.0.0.1:" + $UiPort + "/ >NUL")
  if($LASTEXITCODE -eq 0){
    Say ("UI OK: http://127.0.0.1:" + $UiPort + "/") Green
  } else {
    Say ("UI FAIL: curl exit " + $LASTEXITCODE) Red
  }
} catch {
  Say ("UI FAIL: " + $_.Exception.Message) Red
}

# 2) TLS check should hit the DOMAIN (not https://127.0.0.1)
try{
  $hdr = cmd.exe /c ("curl.exe -k -sS --max-time " + $TimeoutSec + " -I https://" + $Domain + "/")
  if($LASTEXITCODE -eq 0){
    Say ("TLS OK: https://" + $Domain + "/") Green
    $hdr | Out-Host
  } else {
    Say ("TLS FAIL: https://" + $Domain + "/ (curl exit " + $LASTEXITCODE + ")") DarkYellow
    $hdr | Out-Host
  }
} catch {
  Say ("TLS WARN: " + $_.Exception.Message) DarkYellow
}