# === NIFDU_BUILD_RUN_PREVIEW_CONTRACT_INJECTION_V1 ===
try {
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\nifdu\ops\nifdu_contract_start.ps1" -Contract "C:\nifdu\ops\contracts\build_run_preview_contract.json" | Out-Host
} catch {
  Write-Host ("[WARN] Contract start failed: " + $_.Exception.Message)
}
# === END NIFDU_BUILD_RUN_PREVIEW_CONTRACT_INJECTION_V1 ===
# === NIFDU: UI PORT GOVERNOR INJECTION (auto) ===
$__NIFDU_OPS = "C:\nifdu\ops"
$__NIFDU_FREE = Join-Path $__NIFDU_OPS "free_port.ps1"
if(Test-Path $__NIFDU_FREE){
  try{
    powershell -ExecutionPolicy Bypass -File $__NIFDU_FREE -Port 3000 | Out-Host
  } catch {
    Write-Host ("[WARN] free_port.ps1 failed: " + $_.Exception.Message)
  }
}
$env:PORT = "3000"
# === END NIFDU INJECTION ===
# === HARD GUARD: AGENT-3 RUNTIME POLICY ===
Remove-Item Env:PNPM_CONFIG_CONFIRM_MODULES_PURGE -EA SilentlyContinue
Remove-Item Env:PNPM_CONFIG_* -EA SilentlyContinue

function pnpm {
  throw '❌ pnpm is FORBIDDEN inside NIFDU Agent-3 runtime. Use node next dev.'
}
# === END GUARD ===
param(
  [string]$Project   = "sophyane_live",
  [ValidateSet("next","cmake","custom")]
  [string]$Mode      = "next",
  [string]$CustomCmd = "",
  [int]$MaxIters     = 1,
  [int]$TimeoutMs    = 240000
)

$ErrorActionPreference="Stop"

function Say($t,$c="Gray"){ try{ Write-Host $t -ForegroundColor $c } catch { Write-Host $t } }

function Run-Cmd {
  param([Parameter(Mandatory=$true)][string]$CmdLine, [int]$TimeoutMs=240000)
  Say "`n[RUN] cmd.exe /c $CmdLine" DarkGray
  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $CmdLine -PassThru -WindowStyle Hidden
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while(-not $p.HasExited){
    Start-Sleep -Milliseconds 250
    if($sw.ElapsedMilliseconds -gt $TimeoutMs){
      try { $p.Kill() } catch {}
      throw "Timeout after ${TimeoutMs}ms"
    }
  }
  return $p.ExitCode
}

function Start-NextDetached {
  param(
    [string]$AppDir = "C:\nifdu\src\apps\sophyane_live",
    [string]$Log    = ".a3_dev.log"
  )

  $logPath = Join-Path $AppDir $Log
  try { Remove-Item $logPath -Force -EA SilentlyContinue } catch {}

  # Force CI=true only (DO NOT set any PNPM_* env here)
  $env:CI = "true"

  # Start Next via node runner (bypasses pnpm scripts/config entirely)
  $node = "C:\Program Files\nodejs\node.exe"
  if(!(Test-Path $node)){ $node = (Get-Command node -EA Stop).Source }

  $nextBin = Join-Path $AppDir "node_modules\next\dist\bin\next"
  if(!(Test-Path $nextBin)){ throw "Missing next bin: $nextBin (did you run pnpm install?)" }

  # Start-Process redirection writes to files (detached, reliable)
  $p = Start-Process -FilePath $node `
    -ArgumentList @($nextBin,"dev") `
    -WorkingDirectory $AppDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logPath `
    -RedirectStandardError  $logPath `
    -PassThru

  Add-Content -Path $logPath -Encoding UTF8 -Value ("`n[A3] Started Next PID={0} at {1}`n" -f $p.Id,(Get-Date))
  return $p.Id
}

Say "`n=== NIFDU Agent Loop (CLEAN v3 / PS Next Runner) ===" Yellow
Say ("Project: {0} | Mode: {1} | MaxIters: {2}" -f $Project,$Mode,$MaxIters) Cyan

for($iter=1; $iter -le $MaxIters; $iter++){
  Say ("`n--- ITER {0}/{1} ---" -f $iter,$MaxIters) Yellow

  if($Mode -eq "next"){
    $app = "C:\nifdu\src\apps\sophyane_live"
    $stamp = Join-Path $app ".a3_pnpm_lockstamp.txt"
    $lock  = Join-Path $app "pnpm-lock.yaml"

    $hash = "NOLOCK"
    if(Test-Path $lock){
      $fi = Get-Item $lock
      $hash = "{0}_{1}" -f $fi.Length, $fi.LastWriteTimeUtc.ToString("yyyyMMdd_HHmmss")
    }

    $old = ""
    if(Test-Path $stamp){ $old = (Get-Content $stamp -Raw -EA SilentlyContinue).Trim() }

    if($hash -ne $old){
      Say "[A3] lock changed -> reinstall" Yellow

      $nm = Join-Path $app "node_modules"
      if(Test-Path $nm){ try{ Remove-Item $nm -Recurse -Force -EA SilentlyContinue }catch{} }
# Install (non-interactive) — clean mode
      $cmd = "cd /d $app && set CI=true && echo y| pnpm install --silent"
      $code = Run-Cmd -CmdLine $cmd -TimeoutMs $TimeoutMs
      if($code -ne 0){ throw "pnpm install failed exitcode=$code" }

      Set-Content -Path $stamp -Encoding ASCII -Value $hash
    } else {
      Say "[A3] lock unchanged -> skip install" DarkGray
    }

    $pid = Start-NextDetached -AppDir $app -Log ".a3_dev.log"
    Say ("[NEXT] started PID={0}" -f $pid) Cyan
  }
  elseif($Mode -eq "cmake"){
    $cmd = "cd /d C:\nifdu\build && cmake --build . --config Release"
    $code = Run-Cmd -CmdLine $cmd -TimeoutMs $TimeoutMs
    Say ("[CMAKE] exitcode={0}" -f $code) Cyan
  }
  elseif($Mode -eq "custom"){
    if([string]::IsNullOrWhiteSpace($CustomCmd)){ throw "Mode=custom but CustomCmd is empty" }
    $code = Run-Cmd -CmdLine $CustomCmd -TimeoutMs $TimeoutMs
    Say ("[CUSTOM] exitcode={0}" -f $code) Cyan
  }
}

Say "`n[DONE] Agent loop finished" Green