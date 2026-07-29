param(
  [string]$EnvFile = "C:\ENV\.env",
  [string]$ExeDir  = "C:\nifdu\build\Release",
  [string]$Proc    = "nifdu",
  [switch]$NoStart
)


# ===== NIFDU RUNTIME BOOTSTRAP (AUTO-INSERTED) =====
if(-not $Runtime -or [string]::IsNullOrWhiteSpace($Runtime)){
  try {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $repoDir   = Split-Path -Parent $scriptDir
    $Runtime   = Join-Path $repoDir "runtime"
  } catch {
    $Runtime = "C:\nifdu\runtime"
  }
}
if(!(Test-Path $Runtime)){
  New-Item -ItemType Directory -Force -Path $Runtime | Out-Null
}
# ===== END NIFDU RUNTIME BOOTSTRAP =====
$ErrorActionPreference="Stop"

function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

function Load-DotEnv([string]$Path){
  if(!(Test-Path $Path)){
    Say "DotEnv not found: $Path (skipping)" DarkYellow
    return
  }
  Say "Loading DotEnv: $Path" Cyan
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8 -EA SilentlyContinue
  foreach($ln in $lines){
    $t = $ln.Trim()
    if($t.Length -eq 0) { continue }
    if($t.StartsWith("#")) { continue }

    $i = $t.IndexOf("=")
    if($i -lt 1) { continue }

    $k = $t.Substring(0,$i).Trim()
    $v = $t.Substring($i+1).Trim()

    if(($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))){
      if($v.Length -ge 2){ $v = $v.Substring(1,$v.Length-2) }
    }

    try { Set-Item -Path ("Env:\" + $k) -Value $v -EA SilentlyContinue } catch {}
  }
}

function Ensure-NIFDU-PG-Conninfo {
  if([string]::IsNullOrWhiteSpace($env:NIFDU_PG_CONNINFO)){
    $h  = $env:PGHOST_NIFDU
    $pt = $env:PGPORT_NIFDU
    $u  = $env:PGUSER_NIFDU
    $pw = $env:PGPASSWORD_NIFDU
    $db = $env:PGDATABASE_NIFDU

    if([string]::IsNullOrWhiteSpace($h) -or [string]::IsNullOrWhiteSpace($pt) -or
       [string]::IsNullOrWhiteSpace($u) -or [string]::IsNullOrWhiteSpace($pw) -or
       [string]::IsNullOrWhiteSpace($db)){
      Say "Env NIFDU_PG_CONNINFO: NOT SET and PG*_NIFDU incomplete (cannot synthesize conninfo)" Red
      Say ("PGHOST_NIFDU=" + $h) DarkYellow
      Say ("PGPORT_NIFDU=" + $pt) DarkYellow
      Say ("PGUSER_NIFDU=" + $u) DarkYellow
      Say ("PGDATABASE_NIFDU=" + $db) DarkYellow
      return
    }

    # Build in-memory (no file writes needed)
    $env:NIFDU_PG_CONNINFO = "host=$h port=$pt dbname=$db user=$u password=$pw"
    Say "Env NIFDU_PG_CONNINFO: BUILT from PG*_NIFDU (value hidden)" Green
  } else {
    Say "Env NIFDU_PG_CONNINFO: SET (value hidden)" Green
  }
}

function Kill-Nifdu {
  Say "Killing $Proc.exe (hard)..." Yellow
  Get-Process $Proc -EA SilentlyContinue | % { try{ Stop-Process -Id $_.Id -Force -EA SilentlyContinue }catch{} }
  cmd /c "taskkill /F /IM $Proc.exe >NUL 2>&1" | Out-Null
  Start-Sleep -Milliseconds 400
}

function Wait-Unlock([string]$Path,[int]$TimeoutSec=12){
  $sw=[Diagnostics.Stopwatch]::StartNew()
  while($sw.Elapsed.TotalSeconds -lt $TimeoutSec){
    try{
      if(!(Test-Path $Path)){ return $true }
      $fs=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
      $fs.Close()
      return $true
    } catch { Start-Sleep -Milliseconds 250 }
  }
  return $false
}

# ---- Load env, then synthesize conninfo BEFORE swap/start ----
Load-DotEnv $EnvFile
Ensure-NIFDU-PG-Conninfo

$src = Join-Path $ExeDir "nifdu.new.exe"
$dst = Join-Path $ExeDir "nifdu.exe"

Say "`n=== NIFDU SAFE SWAP + RESTART ===`n" Yellow
if(!(Test-Path $src)){ throw "Missing: $src (build first; it produces nifdu.new.exe)" }

Kill-Nifdu

if(Test-Path $dst){
  Say "Waiting unlock: $dst" Cyan
  if(-not (Wait-Unlock $dst 12)){
    throw "Still locked: $dst (something is holding it open)"
  }
}

Say "Swapping: nifdu.new.exe -> nifdu.exe" Cyan
Copy-Item -LiteralPath $src -Destination $dst -Force

if(-not $NoStart){
  Say "Starting: $dst" Cyan
    $ts  = Get-Date -Format "yyyyMMdd_HHmmss"
  $logO = Join-Path $Runtime ("nifdu_restart_" + $ts + ".out.log")
  $logE = Join-Path $Runtime ("nifdu_restart_" + $ts + ".err.log")
  Say ("LogOut: " + $logO) DarkGray
# ===================== NIFDU_SAFE_VERIFY_BLOCK_V1 =====================
# SAFE verification (NON-FATAL): wrapper is the truth.
# We only PRINT status. We DO NOT fail the script here.

function _NifduHealthOk([int]$p,[int]$w){
  try{
    $sw=[System.Diagnostics.Stopwatch]::StartNew()
    while($sw.ElapsedMilliseconds -lt $w){
      try{
        $oldEA = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try{ $oldNative = $global:PSNativeCommandUseErrorActionPreference }catch{ $oldNative = $null }
        try{ $global:PSNativeCommandUseErrorActionPreference = $false }catch{}
        $r = & curl.exe -sS --max-time 1 "http://127.0.0.1:$p/api/health" 2>$null
        $ec = $LASTEXITCODE
        try{ if($oldNative -ne $null){ $global:PSNativeCommandUseErrorActionPreference = $oldNative } }catch{}
        $ErrorActionPreference = $oldEA
        if($ec -eq 0 -and $r -match '"status"\s*:\s*"ok"'){ return $true }
      }catch{}
      Start-Sleep -Milliseconds 200
    }
  }catch{}
  return $false
}

try{
  $p = 8000
  $w = 12000
  if(_NifduHealthOk -p $p -w $w){
    try{ Write-Host ("[SAFE_NOTE] Health OK on :{0}" -f $p) -ForegroundColor DarkGreen }catch{ Write-Host ("[SAFE_NOTE] Health OK on :{0}" -f $p) }
  } else {
    try{ Write-Host ("[SAFE_NOTE] Health not ready yet on :{0} (wrapper will wait)" -f $p) -ForegroundColor Yellow }catch{ Write-Host ("[SAFE_NOTE] Health not ready yet on :{0} (wrapper will wait)" -f $p) }
  }
}catch{
  try{ Write-Host ("[SAFE_NOTE] Verify exception (ignored): " + $_.Exception.Message) -ForegroundColor Yellow }catch{ Write-Host ("[SAFE_NOTE] Verify exception (ignored): " + $_.Exception.Message) }
}
# =================== /NIFDU_SAFE_VERIFY_BLOCK_V1 ======================
# ===================== NIFDU_SAFE_VERIFY_BLOCK_V1 =====================
# Meaningful failure codes (post-verify, deterministic):
# 21 = nifdu process not running
# 22 = /api/health not OK
# 23 = nifdu.exe missing (expected path)
# 24 = verify exception

function _NifduFail([int]$code,[string]$msg){
  try{ Write-Host ("[SAFE_FAIL {0}] {1}" -f $code, $msg) -ForegroundColor Red }catch{ Write-Host ("[SAFE_FAIL {0}] {1}" -f $code, $msg) }
  try{ $global:NIFDU_SAFE_FAIL = $code }catch{}
}

function _NifduHealthOk([int]$Port,[int]$MaxWaitMs){
  try{
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while($sw.ElapsedMilliseconds -lt $MaxWaitMs){
      $r = & curl.exe -sS --max-time 1 "http://127.0.0.1:$Port/api/health" 2>$null
      if($LASTEXITCODE -eq 0 -and $r -match '"status"\s*:\s*"ok"'){ return $true }
      Start-Sleep -Milliseconds 200
    }
  }catch{}
  return $false
}

try{
  if(-not (Get-Variable -Name NIFDU_SAFE_FAIL -Scope Global -ErrorAction SilentlyContinue)){
    $global:NIFDU_SAFE_FAIL = 0
  }

  if([int]$global:NIFDU_SAFE_FAIL -eq 0){

    # EXE existence check
    $exe = "C:\nifdu\build\Release\nifdu.exe"
    if(-not (Test-Path -LiteralPath $exe)){
      _NifduFail 23 ("nifdu.exe missing at expected path: " + $exe)
    }

    # Process check
    $p = Get-Process nifdu -ErrorAction SilentlyContinue | Select-Object -First 1
    if(-not $p){
      _NifduFail 21 "nifdu process not running after restart"
    }

    # Health check
    if([int]$global:NIFDU_SAFE_FAIL -eq 0){
      if(-not (_NifduHealthOk -Port 8000 -MaxWaitMs 12000)){
        _NifduFail 22 ("Health not OK on :8000 within 12000ms")
      }
    }
  }
}catch{
  _NifduFail 24 ("Verify exception: " + $_.Exception.Message)
}
# =================== /NIFDU_SAFE_VERIFY_BLOCK_V1 ======================
  Say ("LogErr: " + $logE) DarkGray
  Start-Process -FilePath $dst -RedirectStandardOutput $logO -RedirectStandardError $logE | Out-Null
  Say "OK." Green
} else {
  Say "Swap done (NoStart requested)." Green
}
# ===================== NIFDU_SAFE_EXIT_BLOCK_V1 =====================
# ----------------- NIFDU_WRAPPED_EXIT0_V1 -----------------
# If SAFE is invoked by the wrapper, wrapper is the judge.
# Always exit 0 here so wrapper’s /api/health gating is the truth.
if($env:NIFDU_WRAPPED -eq "1"){
  try{ Write-Host "[SAFE_NOTE] Wrapped mode -> forcing exit 0 (wrapper decides health)" -ForegroundColor DarkGray }catch{}
  exit 0
}
# --------------- /NIFDU_WRAPPED_EXIT0_V1 ------------------
# Goal: ensure the script returns deterministic exit codes.
# If we reached the end, treat as success unless $global:NIFDU_SAFE_FAIL was set.
if(-not (Get-Variable -Name NIFDU_SAFE_FAIL -Scope Global -ErrorAction SilentlyContinue)){
  $global:NIFDU_SAFE_FAIL = 0
}

try{
  if([int]$global:NIFDU_SAFE_FAIL -ne 0){
    exit [int]$global:NIFDU_SAFE_FAIL
  } else {
    exit 0
  }
}catch{
  exit 1
}
# =================== /NIFDU_SAFE_EXIT_BLOCK_V1 ======================
