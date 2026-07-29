param(
  [string]$Restart = "C:\nifdu\ops\nifdu_restart_safe.ps1",
  [int]$Port       = 8000,
  [int]$MaxWaitMs  = 12000,
  [string]$Runtime = "C:\nifdu\runtime",
  [int]$RestartMaxSec = 90
)

$ErrorActionPreference="Continue"
function Say([string]$t,[string]$c="Gray"){ try{ Write-Host $t -ForegroundColor $c }catch{ Write-Host $t } }
function Ensure-Dir([string]$p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function Wait-NifduHealth([int]$Port,[int]$MaxWaitMs){
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while($sw.ElapsedMilliseconds -lt $MaxWaitMs){
    $r = & curl.exe -sS --max-time 1 "http://127.0.0.1:$Port/api/health" 2>$null
    if($LASTEXITCODE -eq 0 -and $r -match '"status"\s*:\s*"ok"'){ return $true }
    Start-Sleep -Milliseconds 200
  }
  return $false
}

# RECURSION_GUARD
try{
  $self = (Resolve-Path -LiteralPath $PSCommandPath).Path
  $rst  = (Resolve-Path -LiteralPath $Restart).Path
  if($self -eq $rst){
    Say ("ERROR: Wrapper Restart points to itself: " + $rst) Red
    exit 9
  }
}catch{}

Ensure-Dir $Runtime
$ts   = Get-Date -Format "yyyyMMdd_HHmmss"
$logO = Join-Path $Runtime ("restart_wrap_" + $ts + ".out.log")
$logE = Join-Path $Runtime ("restart_wrap_" + $ts + ".err.log")
$ecF  = Join-Path $Runtime ("restart_wrap_" + $ts + ".exitcode.txt")

Say "`n=== NIFDU RESTART (wrapped v7) ===`n" Yellow
Say ("ChildOut: " + $logO) DarkGray
Say ("ChildErr: " + $logE) DarkGray
Say ("ExitCode: " + $ecF) DarkGray
Say ("Restart target: " + $Restart) DarkGray
Say ("Restart timeout: {0}s" -f $RestartMaxSec) DarkGray

# Child command: run script, persist ec, exit ec
# (Write exitcode even if Start-Process ExitCode acts weird)
$cmd = @"
`$ErrorActionPreference='Continue';
`$env:NIFDU_WRAPPED='1';
try{
  & '$Restart'
  `$ec = `$LASTEXITCODE
}catch{
  `$ec = 998
}
if(`$null -eq `$ec){ `$ec = 0 }
try{ Set-Content -LiteralPath '$ecF' -Value `$ec -Encoding Ascii }catch{}
exit `$ec
"@

# Start child and redirect logs
$p = Start-Process -FilePath "powershell.exe" -ArgumentList @(
  "-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd
) -RedirectStandardOutput $logO -RedirectStandardError $logE -PassThru

$done = $p.WaitForExit($RestartMaxSec * 1000)
try{ $p.Refresh() }catch{}

$ec = $null
if(-not $done){
  Say ("Restart child PID: " + $p.Id) DarkGray
  Say "Restart child did not exit in time -> KILL" Red
  try{ Stop-Process -Id $p.Id -Force -EA SilentlyContinue }catch{}
  $ec = 997
}else{
  # Prefer file (most reliable), fallback to ExitCode
  if(Test-Path $ecF){
    try{
      $t = (Get-Content -LiteralPath $ecF -Raw).Trim()
      if($t -match '^\d+$'){ $ec = [int]$t }
    }catch{}
  }
  if($null -eq $ec){
    try{ if($p.HasExited){ $ec = [int]$p.ExitCode } }catch{}
  }
  if($null -eq $ec){ $ec = 0 }
}

Say ("Restart child HasExited: {0}" -f $p.HasExited) DarkGray
Say ("Restart script exit code: {0}" -f $ec) DarkGray

if(Test-Path $logO){ Say "`n--- CHILD OUT (tail) ---" Cyan; Get-Content $logO -Tail 160 | Out-Host }
if(Test-Path $logE){ Say "`n--- CHILD ERR (tail) ---" Cyan; Get-Content $logE -Tail 160 | Out-Host }

Say "`nWaiting for /api/health on :$Port ..." Cyan
if(Wait-NifduHealth -Port $Port -MaxWaitMs $MaxWaitMs){
  Say "NIFDU health OK on :$Port" Green
  Say "`nPROVE /api/brain/meta:" Yellow
  & curl.exe -sS --max-time 2 "http://127.0.0.1:$Port/api/brain/meta" | Out-Host
  exit 0
}else{
  Say "NIFDU did not come online on :$Port within $MaxWaitMs ms" Red
  exit 2
}